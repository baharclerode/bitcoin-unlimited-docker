FROM alpine:3.6 AS builder

RUN apk --no-cache --virtual build-dependendencies add autoconf \
    automake \
    boost-dev \
    build-base \
    chrpath \
    file \
    libevent-dev \
    libressl \
    libressl-dev \
    libtool \
    linux-headers \
    protobuf-dev \
    zeromq-dev \
    git

# Build BerkeleyDB
RUN mkdir -p /opt/berkeleydb /tmp/build
ARG berkeleyDBVersion=db-4.8.30.NC
RUN wget -O /tmp/build/${berkeleyDBVersion}.tar.gz http://download.oracle.com/berkeley-db/${berkeleyDBVersion}.tar.gz
RUN tar -xzf /tmp/build/${berkeleyDBVersion}.tar.gz -C /tmp/build/
WORKDIR /tmp/build/${berkeleyDBVersion}/build_unix
RUN sed s/__atomic_compare_exchange/__atomic_compare_exchange_db/g -i /tmp/build/${berkeleyDBVersion}/dbinc/atomic.h
RUN ../dist/configure --enable-cxx --disable-shared --with-pic --prefix=/opt/berkeleydb
RUN make install
RUN rm -rf /opt/berkeleydb/docks

# Build Bitcoind
RUN mkdir -p /opt/bitcoind
WORKDIR /tmp/build/bitcoind
ARG gitrepo=https://github.com/BitcoinUnlimited/BitcoinUnlimited.git
RUN git clone $gitrepo /tmp/build/bitcoind
ARG revision=master
RUN git fetch origin
RUN git checkout --detach $revision
RUN sed -i '/AC_PREREQ/a\AR_FLAGS=cr' src/univalue/configure.ac
RUN sed -i '/AX_PROG_CC_FOR_BUILD/a\AR_FLAGS=cr' src/secp256k1/configure.ac
RUN sed -i s:sys/fcntl.h:fcntl.h: src/compat.h
RUN ./autogen.sh
RUN ./configure LDFLAGS=-L/opt/berkeleydb/lib/ CPPFLAGS=-I/opt/berkeleydb/include/ \
    --prefix=/opt/bitcoind \
    --disable-tests \
    --disable-bench \
    --disable-ccache \
    --disable-wallet \
    --with-gui=no \
    --with-utils \
    --with-libs \
    --with-daemon \
    --without-miniupnpc
RUN make install
RUN strip /opt/bitcoind/bin/bitcoin-cli /opt/bitcoind/bin/bitcoind /opt/bitcoind/bin/bitcoin-tx /opt/bitcoind/lib/libbitcoinconsensus.a /opt/bitcoind/lib/libbitcoinconsensus.so.0.0.0


# Runtime Image
FROM alpine:3.6

ENV BITCOIN_DATA=/var/lib/bitcoind
WORKDIR /var/lib/bitcoind
VOLUME ["/var/lib/bitcoind"]
EXPOSE 8332 8333 18332 18333 18444

ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["bitcoind"]

RUN adduser -S bitcoin && \
    apk --no-cache add boost boost-program_options libevent libressl libzmq su-exec

ENV PATH=/opt/bitcoind/bin:$PATH

COPY docker-entrypoint.sh /opt/entrypoint.sh
COPY --from=builder /opt/ /opt/

