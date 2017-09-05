FROM nginx:alpine
LABEL maintainer="Christopher Chin <ctchin13@gmail.com>"

# Install ruby
# Pulled from official ruby docker file
# skip installing gem documentation
RUN mkdir -p /usr/local/etc \
	&& { \
		echo 'install: --no-document'; \
		echo 'update: --no-document'; \
	} >> /usr/local/etc/gemrc

ENV RUBY_MAJOR 2.4
ENV RUBY_VERSION 2.4.1
ENV RUBY_DOWNLOAD_SHA256 4fc8a9992de3e90191de369270ea4b6c1b171b7941743614cc50822ddc1fe654
ENV RUBYGEMS_VERSION 2.6.13

# some of ruby's build scripts are written in ruby
#   we purge system ruby later to make sure our final image uses what we just built
# readline-dev vs libedit-dev: https://bugs.ruby-lang.org/issues/11869 and https://github.com/docker-library/ruby/issues/75
RUN set -ex \
	\
	&& apk add --no-cache --virtual .ruby-builddeps \
		autoconf \
		bison \
		bzip2 \
		bzip2-dev \
		ca-certificates \
		coreutils \
		dpkg-dev dpkg \
		gcc \
		gdbm-dev \
		glib-dev \
		libc-dev \
		libffi-dev \
		libressl \
		libressl-dev \
		libxml2-dev \
		libxslt-dev \
		linux-headers \
		make \
		ncurses-dev \
		procps \
		readline-dev \
		ruby \
		tar \
		xz \
		yaml-dev \
		zlib-dev \
	\
	&& wget -O ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.xz" \
	&& echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.xz" | sha256sum -c - \
	\
	&& mkdir -p /usr/src/ruby \
	&& tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1 \
	&& rm ruby.tar.xz \
	\
	&& cd /usr/src/ruby \
	\
# hack in "ENABLE_PATH_CHECK" disabling to suppress:
#   warning: Insecure world writable dir
	&& { \
		echo '#define ENABLE_PATH_CHECK 0'; \
		echo; \
		cat file.c; \
	} > file.c.new \
	&& mv file.c.new file.c \
	\
	&& autoconf \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
# the configure script does not detect isnan/isinf as macros
	&& export ac_cv_func_isnan=yes ac_cv_func_isinf=yes \
	&& ./configure \
		--build="$gnuArch" \
		--disable-install-doc \
		--enable-shared \
	&& make -j "$(nproc)" \
	&& make install \
	\
	&& runDeps="$( \
		scanelf --needed --nobanner --recursive /usr/local \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	)" \
	&& apk add --virtual .ruby-rundeps $runDeps \
		bzip2 \
		ca-certificates \
		libffi-dev \
		libressl-dev \
		procps \
		yaml-dev \
		zlib-dev \
	&& apk del .ruby-builddeps \
	&& cd / \
	&& rm -r /usr/src/ruby \
	\
	&& gem update --system "$RUBYGEMS_VERSION"

ENV BUNDLER_VERSION 1.15.4

RUN gem install bundler --version "$BUNDLER_VERSION"

# install things globally, for great justice
# and don't create ".bundle" in all our apps
ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH="$GEM_HOME" \
	BUNDLE_BIN="$GEM_HOME/bin" \
	BUNDLE_SILENCE_ROOT_WARNING=1 \
	BUNDLE_APP_CONFIG="$GEM_HOME"
ENV PATH $BUNDLE_BIN:$PATH
RUN mkdir -p "$GEM_HOME" "$BUNDLE_BIN" \
	&& chmod 777 "$GEM_HOME" "$BUNDLE_BIN"

# Install Jekyll
# Pulled from official Jekyll dockerfile
# Removed all the meta configurations.
ENV JEKYLL_VAR_DIR=/usr/local/var/jekyll
ENV JEKYLL_VERSION=3.5

RUN apk --no-cache add \
  zlib-dev \
  build-base \
  libxml2-dev \
  libxslt-dev \
  readline-dev \
  libffi-dev \
  yaml-dev \
  zlib-dev \
  libffi-dev \
# End of developer packages. These can be removed after building jekyll
  less \
  zlib \
  libxml2 \
  readline \
  libxslt \
  libffi \
  git \
  nodejs \
  tzdata \
  shadow \
  bash \
  su-exec

RUN echo "gem: --no-ri --no-rdoc" > ~/.gemrc
RUN yes | gem update --system

RUN gem install bundler
RUN gem install jekyll

RUN yes | gem update

ENV PATH=/usr/local/bin:$PATH

# Install uwsgi 
RUN apk update \
    && apk add uwsgi \
    && ln -sf /dev/stdout /var/log/uwsgi.log

COPY uwsgi.ini /etc/uwsgi.ini


STOPSIGNAL SIGTERM

EXPOSE 80
CMD uwsgi --daemonize /var/log/uwsgi.log --ini /etc/uwsgi.ini & nginx -g "daemon off;"
