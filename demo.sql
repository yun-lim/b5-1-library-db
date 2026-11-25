-- =====================================================================
-- demo.sql — 평가 시연용 모음
-- =====================================================================
-- ▶ 시작: VS Code 터미널(Ctrl+`)에 아래 두 줄을 입력한다. (SQL 아님, 셸 명령)
--
--      cd b5-1-library-db
--      sqlite3
--
--    프롬프트가 `sqlite>` 로 바뀌면 준비 완료. 끝낼 때는 `.quit`
--    (리허설: 셸에서  sqlite3 < demo.sql  → 전체 시연이 한 번에 출력)
-- =====================================================================
-- 사용법
--   1) 저장소 폴더에서 `sqlite3` 를 파일 이름 없이 실행한다. (위 ▶ 시작)
--      → 메모리 DB에서 시연하므로 실제 파일이 바뀌지 않는다.
--   2) 아래 [준비] 블록을 먼저 붙여넣는다.
--   3) 평가 질문에 맞는 [블록]을 골라 붙여넣는다. (블록끼리 순서 무관)
--   전체를 한 번에 돌려보려면:  sqlite3 < demo.sql
--   (일부러 막히는 시연이 있어서 마지막 종료 코드는 1 이다. 정상이다.)
--
-- 원칙: 데이터를 바꾸는 시연은 BEGIN ... ROLLBACK 으로 감싸서
--       시연이 끝나면 원래 데이터로 돌아간다.
--       "Error: ... constraint failed" 가 나오는 블록은 '막히는 걸 보여주는' 시연이다.
-- =====================================================================


-- ---------------------------------------------------------------------
-- [준비] 스키마 + 샘플 데이터 적재, 보기 좋은 출력 설정
-- ---------------------------------------------------------------------
.read schema.sql
.read insert.sql
.bail off
.headers on
.mode column
.nullvalue NULL
PRAGMA foreign_keys = ON;


-- =====================================================================
-- 평가 그룹 1 — 결과물/구현 확인
-- =====================================================================

-- ---------------------------------------------------------------------
-- [1-1] 테이블 4개 + 각 테이블의 PK
-- ---------------------------------------------------------------------
.print '[1-1] 테이블 목록'
.tables
-- pk 칸이 1인 컬럼이 PRIMARY KEY 다. (모든 테이블이 id)
.print '[1-1] 각 테이블의 PK 컬럼'
SELECT 'member' AS tbl, name AS pk_column FROM pragma_table_info('member') WHERE pk = 1
UNION ALL SELECT 'category', name FROM pragma_table_info('category') WHERE pk = 1
UNION ALL SELECT 'book', name FROM pragma_table_info('book') WHERE pk = 1
UNION ALL SELECT 'rental', name FROM pragma_table_info('rental') WHERE pk = 1;


-- ---------------------------------------------------------------------
-- [1-2] FK 1:N 관계 3개 + 없는 값 참조가 실제로 막힘
-- ---------------------------------------------------------------------
.print '[1-2] FK 목록 (from 컬럼 → table.to 컬럼)'
-- book.category_id → category.id / rental.member_id → member.id / rental.book_id → book.id
SELECT 'book' AS child, "from", "table" AS parent, "to" FROM pragma_foreign_key_list('book')
UNION ALL
SELECT 'rental', "from", "table", "to" FROM pragma_foreign_key_list('rental');

.print '[1-2] FK 검사가 켜져 있는지 (1 = ON)'
PRAGMA foreign_keys;

.print '[1-2-a] 없는 회원(999번)으로 대여 등록 → FOREIGN KEY constraint failed 가 나와야 정상'
INSERT INTO rental VALUES (99, 999, 1, '2026-10-01', '2026-10-08', NULL, '대여중', 2100);

.print '[1-2-b] 없는 카테고리(999번)로 도서 등록 → 역시 막힘'
INSERT INTO book VALUES (99, 'LIB-999', '유령 책', '저자', 999, 500);

.print '[1-2-c] 반대 방향: 대여 기록이 있는 1번 회원 삭제 → 고아 데이터가 생기므로 막힘'
DELETE FROM member WHERE id = 1;

.print '[1-2-d] 비교: PRAGMA 를 끄면 999번이 그냥 들어간다 (그래서 매 연결마다 ON 이 필요)'
-- PRAGMA foreign_keys 는 트랜잭션 안에서 바꿀 수 없어서 BEGIN 바깥에서 끄고 켠다.
PRAGMA foreign_keys = OFF;
BEGIN;
INSERT INTO rental VALUES (99, 999, 1, '2026-10-01', '2026-10-08', NULL, '대여중', 2100);
SELECT id, member_id FROM rental WHERE id = 99;   -- 들어가 버림 = 고아 데이터
ROLLBACK;
PRAGMA foreign_keys = ON;

.print '[1-2-e] 현재 DB에 FK 위반 행이 하나도 없는지 (결과가 비어 있으면 정상)'
PRAGMA foreign_key_check;


-- ---------------------------------------------------------------------
-- [1-3] 테이블별 행 수 (각 10행 이상)
-- ---------------------------------------------------------------------
.print '[1-3] 테이블별 행 수'
SELECT 'member' AS tbl, COUNT(*) AS row_count FROM member
UNION ALL SELECT 'category', COUNT(*) FROM category
UNION ALL SELECT 'book', COUNT(*) FROM book
UNION ALL SELECT 'rental', COUNT(*) FROM rental;
-- 결과: member 12 / category 10 / book 12 / rental 16
-- (queries.sql 의 Q14 가 1건을 지우므로 results.txt 에는 rental 15 로 나온다)


-- [1-4] 쿼리 15개 → queries.sql 파일 자체를 보여준다.
-- [1-5] 실행 결과 → results/results.txt. 재현은 터미널(셸)에서:
--   tmp=$(mktemp -d)
--   sqlite3 "$tmp/x.db" < schema.sql && sqlite3 "$tmp/x.db" < insert.sql
--   sqlite3 "$tmp/x.db" < queries.sql > "$tmp/out.txt"
--   diff "$tmp/out.txt" results/results.txt && echo "결과 동일"


-- =====================================================================
-- 평가 그룹 2 — 구현 방법 설명
-- =====================================================================

-- ---------------------------------------------------------------------
-- [2-1] 테이블을 나눈 이유: 회원 이름은 한 곳에만 있다
-- ---------------------------------------------------------------------
.print '[2-1] 1번 회원 이름을 한 번만 고치면, 대여 기록 3건 모두에 반영된다'
BEGIN;
UPDATE member SET name = '김하늘(개명)' WHERE id = 1;
SELECT r.id AS rental_id, m.name, b.title
FROM rental AS r
JOIN member AS m ON r.member_id = m.id
JOIN book AS b ON r.book_id = b.id
WHERE m.id = 1;
ROLLBACK;
-- 엑셀처럼 대여 행마다 이름을 적었다면 3칸을 다 고쳐야 하고, 하나라도 빠뜨리면 데이터가 어긋난다.


-- ---------------------------------------------------------------------
-- [2-2] 1:N 관계의 실제 의미
-- ---------------------------------------------------------------------
.print '[2-2-a] 회원 1명(1) : 대여 여러 건(N) — 김하늘의 대여 기록'
SELECT m.id AS member_id, m.name, r.id AS rental_id, r.rented_on, r.status
FROM member AS m JOIN rental AS r ON r.member_id = m.id
WHERE m.id = 1;

.print '[2-2-b] 카테고리 1개(1) : 도서 여러 권(N) — 소설 카테고리의 책'
SELECT c.name AS category, b.id AS book_id, b.title
FROM category AS c JOIN book AS b ON b.category_id = c.id
WHERE c.id = 1;

.print '[2-2-c] 도서 1권(1) : 대여 여러 번(N) — 같은 책이 여러 번 빌려짐'
SELECT b.title, COUNT(r.id) AS times_rented
FROM book AS b JOIN rental AS r ON r.book_id = b.id
GROUP BY b.id HAVING COUNT(r.id) > 1;


-- ---------------------------------------------------------------------
-- [2-3] 컬럼 타입과 제약조건
-- ---------------------------------------------------------------------
.print '[2-3-a] 돈을 REAL(소수)로 저장하면 안 되는 이유: 0.1+0.2 = 0.3 ? (0 = 거짓)'
SELECT 0.1 + 0.2 = 0.3 AS is_equal, (0.1 + 0.2) - 0.3 AS difference;

.print '[2-3-b] 날짜를 YYYY-MM-DD 로 0을 채워 쓰는 이유 (1 = 참)'
SELECT '2026-09-27' < '2026-10-04' AS zero_padded,   -- 1 : 날짜 순서와 같음
       '2026-9-27'  < '2026-10-04' AS not_padded;    -- 0 : 틀린 결과

.print '[2-3-c] 없는 날짜(2월 30일) → CHECK constraint failed'
INSERT INTO member VALUES (99, '테스트', 'test@example.com', '2026-02-30');

.print '[2-3-d] 중복 이메일 → UNIQUE constraint failed'
INSERT INTO member VALUES (99, '테스트', 'haneul@example.com', '2026-10-01');

.print '[2-3-e] 정해진 3개 외의 상태값 → CHECK constraint failed'
INSERT INTO rental VALUES (99, 1, 1, '2026-10-01', '2026-10-08', NULL, '분실', 2100);

.print '[2-3-f] 음수 대여료 → CHECK constraint failed'
INSERT INTO book VALUES (99, 'LIB-999', '테스트 책', '저자', 1, -100);

.print '[2-3-g] 반납기한이 대여일보다 앞섬 → CHECK constraint failed'
INSERT INTO rental VALUES (99, 1, 1, '2026-10-08', '2026-10-01', NULL, '대여중', 2100);

.print '[2-3-h] (한계) SQLite 는 타입이 유연해서 INTEGER 칸에 문자가 들어간다'
BEGIN;
INSERT INTO book VALUES (99, 'LIB-999', '테스트 책', '저자', 1, 'abc');
SELECT daily_fee, typeof(daily_fee) AS stored_type FROM book WHERE id = 99;  -- abc / text
ROLLBACK;
-- 보완책: CHECK (typeof(daily_fee) = 'integer') 를 추가하거나 STRICT 테이블을 쓴다.


-- ---------------------------------------------------------------------
-- [2-4] 인덱스: rented_on 에 건 이유 (실행 계획 비교)
-- ---------------------------------------------------------------------
-- Q03 처럼 "기간으로 대여 기록 찾기"는 자주 쓰는 검색이다.
BEGIN;
.print '[2-4] 인덱스 전: SCAN rental (전체 훑기) + USE TEMP B-TREE (정렬 따로 함)'
EXPLAIN QUERY PLAN SELECT id, rented_on FROM rental
WHERE rented_on BETWEEN '2026-09-05' AND '2026-10-04' ORDER BY rented_on, id;

CREATE INDEX idx_rental_rented_on ON rental(rented_on);

.print '[2-4] 인덱스 후: SEARCH ... USING COVERING INDEX (범위만 바로 찾음, 정렬도 생략)'
EXPLAIN QUERY PLAN SELECT id, rented_on FROM rental
WHERE rented_on BETWEEN '2026-09-05' AND '2026-10-04' ORDER BY rented_on, id;
ROLLBACK;
-- 인덱스는 이미 날짜순으로 정렬된 목차라서, 범위의 시작점을 찾아 끝까지 읽기만 하면 된다.


-- =====================================================================
-- 평가 그룹 3 — 개념 이해
-- =====================================================================

-- [3-1] DB vs 엑셀 → [2-1](한 곳만 수정) + [1-2](잘못된 값 거부) + [2-3](규칙 강제) 를 보여준다.
-- [3-2] PK vs FK  → [1-1](PK) + [1-2](FK 목록과 차단) + [2-2](1:N) 를 보여준다.

-- ---------------------------------------------------------------------
-- [3-3] INNER JOIN vs LEFT JOIN
-- ---------------------------------------------------------------------
.print '[3-3-a] 10번 시 카테고리 — INNER JOIN: 책이 없어서 아무것도 안 나온다'
SELECT c.name, b.title FROM category c INNER JOIN book b ON b.category_id = c.id WHERE c.id = 10;

.print '[3-3-b] 10번 시 카테고리 — LEFT JOIN: 카테고리는 남고 책 칸은 NULL'
SELECT c.name, b.title FROM category c LEFT JOIN book b ON b.category_id = c.id WHERE c.id = 10;

.print '[3-3-c] 전체 행 수 비교: INNER 12행 vs LEFT 13행 (차이 1행 = 시)'
SELECT (SELECT COUNT(*) FROM category c INNER JOIN book b ON b.category_id = c.id) AS inner_rows,
       (SELECT COUNT(*) FROM category c LEFT  JOIN book b ON b.category_id = c.id) AS left_rows;

.print '[3-3-d] 회원 쪽: INNER 면 11·12번 회원이 사라지고, LEFT 면 NULL 로 남는다'
SELECT m.id, m.name, r.id AS rental_id FROM member m INNER JOIN rental r ON r.member_id = m.id WHERE m.id >= 10;
SELECT m.id, m.name, r.id AS rental_id FROM member m LEFT  JOIN rental r ON r.member_id = m.id WHERE m.id >= 10;

.print '[3-3-e] 응용: LEFT JOIN + IS NULL = 짝이 없는 것만 찾기'
SELECT c.name AS empty_category FROM category c LEFT JOIN book b ON b.category_id = c.id WHERE b.id IS NULL;


-- ---------------------------------------------------------------------
-- [3-4] GROUP BY 와 집계 함수 (COUNT / SUM / AVG)
-- ---------------------------------------------------------------------
.print '[3-4-a] 묶기 전 원본: rental 의 상태와 금액'
SELECT id, status, rental_fee FROM rental ORDER BY status, id;

.print '[3-4-b] GROUP BY status: 같은 상태끼리 한 줄로 접고 COUNT/SUM'
SELECT status, COUNT(*) AS cnt, SUM(rental_fee) AS total_fee FROM rental GROUP BY status;

.print '[3-4-c] AVG 손검산: 소설(300, 400) → 350 / 컴퓨터(700, 800) → 750'
SELECT category_id, GROUP_CONCAT(daily_fee) AS fees, AVG(daily_fee) AS avg_fee
FROM book WHERE category_id IN (1, 5) GROUP BY category_id;

.print '[3-4-d] COUNT(*) vs COUNT(r.id): 대여 0회인 11·12번 회원'
-- COUNT(*) 는 행 자체를 세서 NULL 행도 1로 센다 (틀림).
-- COUNT(r.id) 는 NULL 이 아닌 값만 센다 → 0 (맞음). 그래서 Q09 는 COUNT(r.id) 를 쓴다.
SELECT m.id, m.name, COUNT(*) AS count_star, COUNT(r.id) AS count_rid
FROM member m LEFT JOIN rental r ON r.member_id = m.id
WHERE m.id >= 10 GROUP BY m.id, m.name;


-- =====================================================================
-- 평가 그룹 4 — 응용·확장
-- =====================================================================

-- ---------------------------------------------------------------------
-- [4-1] 가장 복잡한 쿼리 Q09 를 단계별로 쌓아 보기
-- ---------------------------------------------------------------------
.print '[4-1 1단계] 회원 테이블에서 시작 (12명)'
SELECT id, name FROM member;

.print '[4-1 2단계] LEFT JOIN 으로 대여 기록을 붙임 (대여 없는 회원도 NULL 로 남음)'
SELECT m.id, m.name, r.id AS rental_id
FROM member m LEFT JOIN rental r ON r.member_id = m.id ORDER BY m.id, r.id;

.print '[4-1 3단계] GROUP BY 로 회원별 한 줄로 접고 COUNT(r.id) 로 셈'
SELECT m.id, m.name, COUNT(r.id) AS rental_count
FROM member m LEFT JOIN rental r ON r.member_id = m.id
GROUP BY m.id, m.name;

.print '[4-1 4단계] ORDER BY 로 많이 빌린 순 정렬 = 완성된 Q09'
SELECT m.id, m.name, COUNT(r.id) AS rental_count
FROM member m LEFT JOIN rental r ON r.member_id = m.id
GROUP BY m.id, m.name ORDER BY rental_count DESC, m.id;


-- ---------------------------------------------------------------------
-- [4-2] 어려웠던 점 시연 (보조)
-- ---------------------------------------------------------------------
-- (1) FK 가 기본으로 꺼져 있던 문제        → [1-2-d] 시연
-- (2) 날짜 타입이 없어서 문자열 비교 문제  → [2-3-b] 시연
-- (3) 0회 회원이 사라지던 문제             → [3-4-d] 시연
-- (4) UPDATE/DELETE 가 의도한 행만 바뀌는지 → 아래 시연
.print '[4-2] Q13 UPDATE: 기준일 전 마감인 미반납 건만 연체로 (몇 행 바뀌었는지 changes() 로 확인)'
BEGIN;
UPDATE rental SET status = '연체'
WHERE status = '대여중' AND returned_on IS NULL AND due_on < '2026-10-04';
SELECT changes() AS updated_rows;
SELECT id, due_on, status FROM rental WHERE returned_on IS NULL ORDER BY id;
ROLLBACK;

.print '[4-2] Q14 DELETE: id 와 상태를 둘 다 조건으로 걸어 정확히 1행만 삭제'
BEGIN;
DELETE FROM rental WHERE id = 16 AND status = '반납완료';
SELECT changes() AS deleted_rows;
ROLLBACK;

.print '시연 끝 — 모든 변경은 ROLLBACK 되어 원래 데이터 그대로입니다.'
