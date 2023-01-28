CREATE TABLE tweeters(
  handle varchar(40) not null unique,
  id bigserial primary key
);

CREATE TABLE tweets(
  by  varchar(40) not null references tweeters(handle),
  id bigserial primary key,
  tweet varchar(250)
);

CREATE TABLE followers(
  ee  varchar(40) not null references tweeters(handle),
  er  varchar(40) not null references tweeters(handle)
)
