FROM locustio/locust
RUN pip install locust-plugins playwright && playwright install chromium
USER root
RUN apt-get update && apt-get install -y \
    libnss3 \
    libxss1 \
    libatk-bridge2.0-0 \
    libgtk-3-0 \
    libx11-xcb1 \
    libdbus-glib-1-2 \
    libasound2 \
    fonts-liberation \
    libxrandr2 \
    libgbm1 \
    libxcomposite1 \
    libxcursor1 \
    libxi6 \
    libxtst6 \
    libxrandr2 \
    libgconf-2-4 \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
USER locust
WORKDIR /home/locust
ENTRYPOINT ["locust"]
