-- SQLite CLI 실행 파일. 모든 연결에서 FK 검사를 켠다.
.bail on
PRAGMA foreign_keys = ON;

CREATE TABLE member (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL CHECK (length(trim(name)) > 0),
    email TEXT NOT NULL UNIQUE,
    joined_on TEXT NOT NULL CHECK (length(joined_on) = 10 AND date(joined_on, '+0 days') IS NOT NULL AND date(joined_on, '+0 days') = joined_on)
);

CREATE TABLE category (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE CHECK (length(trim(name)) > 0),
    description TEXT NOT NULL
);

-- book 한 행은 실제로 대여할 수 있는 소장 도서 한 권이다.
CREATE TABLE book (
    id INTEGER PRIMARY KEY,
    inventory_code TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL CHECK (length(trim(title)) > 0),
    author TEXT NOT NULL,
    category_id INTEGER NOT NULL REFERENCES category(id),
    daily_fee INTEGER NOT NULL CHECK (daily_fee >= 0)
);

CREATE TABLE rental (
    id INTEGER PRIMARY KEY,
    member_id INTEGER NOT NULL REFERENCES member(id),
    book_id INTEGER NOT NULL REFERENCES book(id),
    rented_on TEXT NOT NULL CHECK (length(rented_on) = 10 AND date(rented_on, '+0 days') IS NOT NULL AND date(rented_on, '+0 days') = rented_on),
    due_on TEXT NOT NULL CHECK (length(due_on) = 10 AND date(due_on, '+0 days') IS NOT NULL AND date(due_on, '+0 days') = due_on),
    returned_on TEXT CHECK (returned_on IS NULL OR (length(returned_on) = 10 AND date(returned_on, '+0 days') IS NOT NULL AND date(returned_on, '+0 days') = returned_on)),
    status TEXT NOT NULL CHECK (status IN ('대여중', '반납완료', '연체')),
    rental_fee INTEGER NOT NULL CHECK (rental_fee >= 0),
    CHECK (due_on >= rented_on),
    CHECK (returned_on IS NULL OR returned_on >= rented_on),
    CHECK ((status = '반납완료' AND returned_on IS NOT NULL)
        OR (status IN ('대여중', '연체') AND returned_on IS NULL))
);
