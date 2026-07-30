FROM ruby:4.0.6-slim

ENV BUNDLER_VERSION=4.0.17

RUN apt-get update -qq && apt-get install -y build-essential

WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN gem install bundler -v "${BUNDLER_VERSION}" --no-document && bundle install

COPY app.rb config.ru ./

CMD ["bundle", "exec", "rackup", "-p", "4567", "-o", "0.0.0.0"]
