#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int32_t macwarden_write_new_file(kk_string_t path, kk_string_t content,
                                        kk_context_t* ctx) {
  kk_ssize_t path_len;
  kk_ssize_t content_len;
  const char* target = kk_string_cbuf_borrow(path, &path_len, ctx);
  const uint8_t* bytes = kk_string_buf_borrow(content, &content_len, ctx);
  const char suffix[] = ".tmp.XXXXXX";
  char* temporary = malloc((size_t)path_len + sizeof(suffix));
  int err = 0;
  int fd = -1;

  if (temporary == NULL) {
    err = ENOMEM;
  } else {
    memcpy(temporary, target, (size_t)path_len);
    memcpy(temporary + path_len, suffix, sizeof(suffix));
    fd = mkstemp(temporary);
    if (fd < 0) err = errno;
  }

  size_t offset = 0;
  while (err == 0 && offset < (size_t)content_len) {
    ssize_t written = write(fd, bytes + offset, (size_t)content_len - offset);
    if (written < 0) {
      if (errno == EINTR) continue;
      err = errno;
    } else if (written == 0) {
      err = EIO;
    } else {
      offset += (size_t)written;
    }
  }

  if (fd >= 0) {
    if (err == 0 && fsync(fd) != 0) err = errno;
    if (close(fd) != 0 && err == 0) err = errno;
  }
  if (err == 0 && link(temporary, target) != 0) err = errno;
  if (temporary != NULL && fd >= 0) unlink(temporary);
  if (err == 0) {
    memcpy(temporary, target, (size_t)path_len);
    temporary[path_len] = '\0';
    char* slash = strrchr(temporary, '/');
    if (slash == NULL) {
      temporary[0] = '.';
      temporary[1] = '\0';
    } else if (slash == temporary) {
      slash[1] = '\0';
    } else {
      *slash = '\0';
    }
    int directory = open(temporary, O_RDONLY | O_DIRECTORY);
    if (directory < 0) {
      err = errno;
    } else {
      if (fcntl(directory, F_FULLFSYNC) != 0) err = errno;
      close(directory);
    }
  }

  free(temporary);
  kk_string_drop(path, ctx);
  kk_string_drop(content, ctx);
  return (int32_t)err;
}
