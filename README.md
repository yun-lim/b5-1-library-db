# B5-1 도서 대여 데이터베이스

SQLite로 회원, 소장 도서, 카테고리, 대여 기록을 관리하는 SQL 데이터베이스다. SQL만 사용하며 실행 도구는 `sqlite3` CLI다.

## 프로젝트 파일

| 파일 | 역할 |
| --- | --- |
| [schema.sql](schema.sql) | `member`, `category`, `book`, `rental` 테이블과 제약조건 정의 |
| [insert.sql](insert.sql) | 실행 재현용 샘플 데이터 입력 |
| [queries.sql](queries.sql) | Q01~Q15 조회·수정·삭제·인덱스 SQL |
| [results/results.txt](results/results.txt) | 쿼리 실행 결과 |

## 실행 및 결과 재현

검증 환경: macOS / SQLite 3.51.0. 별도 서버, 백엔드 프레임워크, 추가 패키지가 필요 없다. 터미널에서 다음 순서로 실행한다.

```sh
cd b5-1-library-db
sqlite3 --version
run_dir=$(mktemp -d /tmp/b5-1-replay.XXXXXX)
sqlite3 "$run_dir/library.db" < schema.sql
sqlite3 "$run_dir/library.db" < insert.sql
sqlite3 "$run_dir/library.db" < queries.sql > "$run_dir/results.txt"
cat "$run_dir/results.txt"
diff -u results/results.txt "$run_dir/results.txt"
```

`diff` 출력이 없으면 제출 결과와 같다. 실행 계획의 표현은 SQLite 버전에 따라 달라질 수 있다. 생성한 DB와 결과는 `$run_dir`에 남아 직접 열어볼 수 있다. 각 명령이 성공한 뒤 다음 명령을 실행한다. 재실행할 때는 위 명령으로 새 디렉터리와 새 DB를 만든다. 동일한 DB에 다시 실행하면 테이블·인덱스 중복 오류가 나거나 수정 전 상태가 달라진다.

모든 스크립트는 `.bail on`으로 오류가 나면 해당 스크립트를 중단한다. `.print`, `.headers`, `.mode` 등 점 명령은 SQLite CLI 전용이므로 일반 DB GUI의 SQL 편집기에 그대로 붙여 넣지 않는다. `PRAGMA foreign_keys = ON`은 연결마다 필요하므로 세 파일에 모두 적었다. 외래 키는 참조 대상이 없는 입력을 거부하며, 부모 행의 삭제·키 변경도 연결된 자식이 있으면 기본 동작인 `NO ACTION`으로 거부한다. SQLite 전용 날짜 함수, PRAGMA, 실행 계획 구문은 SQL에 주석을 달았다.

실행 결과는 [results/results.txt](results/results.txt)에 Q01~Q15 순서로 저장했다. Q13~Q15의 추가 SELECT·PRAGMA·실행 계획은 변경 결과를 증명하는 보조 확인 구문이다. Q01~Q12는 초기 16건의 대여를 대상으로 한다. Q13은 3건을 연체로 갱신하고 Q14는 정정 대상 1건을 삭제하므로, 끝난 DB에서 이전 조회를 다시 실행하면 일부 결과가 달라진다.

## 테이블 개요

| 테이블 | 역할과 주요 컬럼 | 최초 행 수 |
| --- | --- | ---: |
| member | 회원 ID, 이름, 이메일, 가입일 | 12 |
| category | 카테고리 ID, 이름, 설명 | 10 |
| book | 소장 도서 ID, 등록번호, 제목, 저자, 카테고리 ID, 일일 대여료 | 12 |
| rental | 대여 ID, 회원 ID, 도서 ID, 대여일, 반납 기한, 실제 반납일, 상태, 약정 대여료 | 16 |

`schema.sql`에는 `category → book`, `member → rental`, `book → rental` 1:N 외래 키 관계가 정의되어 있다. `book`은 대여 가능한 소장본을, `rental`은 회원이 소장본을 빌린 기록을 나타낸다.

## 쿼리 목록과 결과

| 번호 | 분류 | 쿼리 구성 | 실제 결과의 확인 지점 |
| --- | --- | --- | --- |
| Q01 | 기본 조회 | WHERE / ORDER BY | 500원 이하 도서 8권, 요금과 ID 오름차순 |
| Q02 | 기본 조회 | ORDER BY / LIMIT | 신규 회원 12·11·10번 3명 |
| Q03 | 기본 조회 | 날짜 범위 WHERE | 대여 5~15번, 총 11건 |
| Q04 | 기본 조회 | 상태 WHERE / ORDER BY | 반납완료 10건, 반납일 최신순 |
| Q05 | 조인 | INNER JOIN | 미반납 6건에 회원 이름과 책 제목 표시 |
| Q06 | 조인 | INNER JOIN | 도서 12권의 카테고리 표시 |
| Q07 | 조인 | INNER JOIN | 대여 이력이 있는 회원과 대여 상세 16행 |
| Q08 | 조인 | LEFT JOIN | 카테고리 10번도 유지되며 book_id와 title은 NULL |
| Q09 | 집계 | GROUP BY / COUNT | 김하늘 3회, 한소율·오준서 0회 |
| Q10 | 집계 | GROUP BY / SUM | 대여중 18,200원, 반납완료 37,100원 |
| Q11 | 집계 | GROUP BY / AVG | 소설 350원, 과학 550원, 컴퓨터 750원 |
| Q12 | 서브쿼리 | NOT EXISTS | 대여 이력 없는 회원 11·12번 |
| Q13 | 수정 | UPDATE | 대여 10·11·12번 연체, 변경 3행 |
| Q14 | 삭제 | DELETE | 대여 16번 삭제 1행, 대상 잔여 0행, 전체 15행 |
| Q15 | 인덱스 | CREATE INDEX | 인덱스 목록 및 SCAN → SEARCH 실행 계획 |

Q03과 Q13은 기준일을 **2026-10-04**로 고정해 실행한다. 따라서 결과가 시스템의 현재 날짜에 따라 달라지지 않는다.

## 검증 결과

새 DB에서 세 스크립트를 순서대로 실행해 결과를 저장했다. `PRAGMA integrity_check;` 결과는 `ok`, `PRAGMA foreign_key_check;` 결과는 위반 행 없이 비어 있었다. 쿼리 실행 후 행 수는 member 12, category 10, book 12, rental 15다. 이 검사는 데이터가 무결성 규칙을 만족함을 확인한다.
