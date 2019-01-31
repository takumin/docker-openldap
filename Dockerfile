# vim: set ft=dockerfile :

#
# Build Container
#

FROM alpine AS build
LABEL maintainer "Takumi Takahashi <takumiiinn@gmail.com>"

RUN echo "Build Config Starting" \
 && apk --update add \
    wget \
    ca-certificates \
 && echo "Build Config Complete!"

# Install Dockerize
ENV DOCKERIZE_VERSION v0.6.1
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz

# Copy Entrypoint Script
COPY ./injection/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh

#
# Deploy Container
#

FROM alpine AS prod
LABEL maintainer "Takumi Takahashi <takumiiinn@gmail.com>"

COPY --from=build /usr/local /usr/local

RUN echo "Deploy Config Starting" \
 && apk --no-cache --update add \
    su-exec \
    runit \
    openldap \
    openldap-backend-all \
    openldap-overlay-all \
 && mkdir -p /usr/share/openldap \
 && mv /etc/openldap/schema /usr/share/openldap/schema \
 && rm -fr /etc/openldap \
 && rm -fr /var/lib/openldap \
 && echo "Deploy Config Complete!"

VOLUME ["/etc/openldap", "/var/lib/openldap"]
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["openldap"]
EXPOSE 389/tcp 636/tcp
