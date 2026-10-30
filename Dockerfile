# Sanskrit Composer Studio — online edition
# Debian's Ruby (3.1) with WEBrick, and the sqlite3 command-line tool the server queries through.
FROM debian:bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ruby ruby-webrick sqlite3 ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 1000 studio
WORKDIR /srv/studio

COPY --chown=studio:studio lib/ lib/
COPY --chown=studio:studio public/ public/
COPY --chown=studio:studio data/reference.sqlite data/cologne.sqlite data/

USER studio
ENV BIND_ADDRESS=0.0.0.0 \
    PORT=7860 \
    LANG=C.UTF-8
EXPOSE 7860

HEALTHCHECK --interval=60s --timeout=5s CMD ruby -rnet/http -e 'exit Net::HTTP.get_response(URI("http://127.0.0.1:#{ENV["PORT"]}/api/config")).is_a?(Net::HTTPSuccess) ? 0 : 1'

CMD ["ruby", "lib/server.rb"]
