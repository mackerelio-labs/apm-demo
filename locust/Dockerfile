FROM locustio/locust:2.44.4
USER root
RUN pip install --no-cache-dir locust-plugins playwright \
    && playwright install --with-deps chromium \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
USER locust
WORKDIR /home/locust
ENTRYPOINT ["locust"]
