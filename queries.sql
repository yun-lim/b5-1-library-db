-- sqlite3 CLI에서 실행한다. 점(.) 명령은 SQL이 아닌 출력/실행 설정이다.
.bail on
.headers on
.mode list
.separator " | "
.nullvalue NULL
PRAGMA foreign_keys = ON;
.print 도서 대여 실습 / 기준일 2026-10-04 / 금액 단위 원
.print Q01 기본 조회: 일일 대여료가 500원 이하인 도서
-- Q01: 저렴한 도서를 요금과 ID 순서로 확인한다.
SELECT id, title, daily_fee FROM book WHERE daily_fee <= 500 ORDER BY daily_fee, id;

.print Q02 기본 조회: 가장 최근 가입한 회원 3명
-- Q02: 가입일 역순으로 정렬하여 신규 회원 3명을 확인한다.
SELECT id, name, joined_on FROM member ORDER BY joined_on DESC, id LIMIT 3;

.print Q03 기본 조회: 최근 30일 대여 기록
-- Q03: 기준일 포함 30일(2026-09-05~2026-10-04)의 대여 기록을 확인한다. date()는 SQLite 날짜 함수다.
SELECT id, member_id, book_id, rented_on FROM rental
WHERE rented_on BETWEEN date('2026-10-04', '-29 days') AND '2026-10-04'
ORDER BY rented_on, id;

.print Q04 기본 조회: 반납이 완료된 최근 대여 기록
-- Q04: 반납완료 기록을 반납일이 최근인 순서로 확인한다.
SELECT id, rented_on, returned_on, rental_fee FROM rental
WHERE status = '반납완료' ORDER BY returned_on DESC, id;

.print Q05 INNER JOIN: 현재 대여 중인 책과 회원
-- Q05: 미반납 대여 기록에 책 제목과 회원 이름을 연결한다(연체 포함).
SELECT r.id, m.name, b.title, r.due_on, r.status FROM rental AS r
INNER JOIN member AS m ON r.member_id = m.id
INNER JOIN book AS b ON r.book_id = b.id
WHERE r.returned_on IS NULL ORDER BY r.due_on, r.id;

.print Q06 INNER JOIN: 도서별 카테고리
-- Q06: 각 도서에 연결된 카테고리 이름을 확인한다.
SELECT b.id, b.title, c.name AS category_name FROM book AS b
INNER JOIN category AS c ON b.category_id = c.id ORDER BY b.id;

.print Q07 INNER JOIN: 회원별 대여 이력 상세
-- Q07: 대여 기록이 있는 회원과 해당 대여 ID를 확인한다.
SELECT m.id AS member_id, m.name, r.id AS rental_id, r.rented_on FROM member AS m
INNER JOIN rental AS r ON r.member_id = m.id ORDER BY m.id, r.id;

.print Q08 LEFT JOIN: 미입고 카테고리를 포함한 도서 목록
-- Q08: 책이 없는 카테고리도 남겨 카테고리별 소장 도서를 확인한다.
SELECT c.id AS category_id, c.name AS category_name, b.id AS book_id, b.title FROM category AS c
LEFT JOIN book AS b ON b.category_id = c.id ORDER BY c.id, b.id;

.print Q09 집계 COUNT: 회원별 대여 횟수
-- Q09: 대여 이력이 없는 회원을 0회로 포함해 회원별 대여 횟수를 집계한다.
SELECT m.id, m.name, COUNT(r.id) AS rental_count FROM member AS m
LEFT JOIN rental AS r ON r.member_id = m.id
GROUP BY m.id, m.name ORDER BY rental_count DESC, m.id;

.print Q10 집계 SUM: 상태별 약정 대여료 합계
-- Q10: 대여 상태별로 대여 시 확정한 금액을 합산한다(실제 수납액이 아님).
SELECT status, SUM(rental_fee) AS total_fee FROM rental GROUP BY status ORDER BY status;

.print Q11 집계 AVG: 카테고리별 평균 일일 대여료
-- Q11: 도서가 있는 카테고리별 평균 요금을 구한다. ROUND()로 소수 둘째 자리까지 표시한다.
SELECT category_id, ROUND(AVG(daily_fee), 2) AS average_daily_fee FROM book
GROUP BY category_id ORDER BY category_id;

.print Q12 서브쿼리: 대여 기록이 없는 회원
-- Q12: 해당 회원의 대여 기록이 존재하지 않는 경우에만 회원을 선택한다.
SELECT m.id, m.name FROM member AS m
WHERE NOT EXISTS (SELECT 1 FROM rental AS r WHERE r.member_id = m.id) ORDER BY m.id;

.print Q13 UPDATE: 연체 상태 갱신
-- Q13: 기준일보다 반납 기한이 지난 미반납 대여를 연체로 갱신한다(당일 마감은 제외).
.print 수정 전
SELECT id, due_on, returned_on, status FROM rental WHERE returned_on IS NULL ORDER BY id;
UPDATE rental SET status = '연체'
WHERE status = '대여중' AND returned_on IS NULL AND due_on < '2026-10-04';
-- changes()는 SQLite 전용이며 직전 UPDATE의 변경 행 수를 증빙한다.
SELECT changes() AS updated_rows;
.print 수정 후
SELECT id, due_on, returned_on, status FROM rental WHERE returned_on IS NULL ORDER BY id;

.print Q14 DELETE: 잘못 등록한 반납완료 대여 기록 정리
-- Q14: 정정 대상인 대여 16번만 삭제하고 해당 기록이 사라졌는지 확인한다.
.print 삭제 전
SELECT id, member_id, book_id, status FROM rental WHERE id = 16;
DELETE FROM rental WHERE id = 16 AND status = '반납완료';
SELECT changes() AS deleted_rows;
.print 삭제 후
SELECT COUNT(*) AS remaining_target_rows FROM rental WHERE id = 16;
SELECT COUNT(*) AS total_rental_rows FROM rental;

.print Q15 INDEX: 대여일 범위 검색용 인덱스
-- Q15: Q03처럼 대여일 범위를 검색할 때 전체 스캔 대신 날짜 범위를 찾도록 rented_on에 인덱스를 생성한다.
.print 생성 전 실행 계획
-- EXPLAIN QUERY PLAN과 PRAGMA는 SQLite 전용 확인 구문이다.
EXPLAIN QUERY PLAN SELECT id, rented_on FROM rental
WHERE rented_on BETWEEN '2026-09-05' AND '2026-10-04' ORDER BY rented_on, id;
CREATE INDEX idx_rental_rented_on ON rental(rented_on);
.print 인덱스 목록
PRAGMA index_list('rental');
.print 생성 후 실행 계획
EXPLAIN QUERY PLAN SELECT id, rented_on FROM rental
WHERE rented_on BETWEEN '2026-09-05' AND '2026-10-04' ORDER BY rented_on, id;
