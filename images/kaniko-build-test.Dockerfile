FROM cgr.dev/chainguard/wolfi-base:latest

# install some software
RUN apk add --no-cache \
  git \
  jq \
  wget

# echo "hello world" on launch
CMD ["echo", "hello world"]
