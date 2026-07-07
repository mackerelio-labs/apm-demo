FROM ruby:3.4.4-slim

RUN apt-get update -qq && apt-get install -y build-essential

WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY app.rb config.ru ./

CMD ["bundle", "exec", "rackup", "-p", "4567", "-o", "0.0.0.0"]
