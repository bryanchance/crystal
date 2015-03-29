require "./time"

lib LibC
  enum FCNTL
    F_GETFL = 3
    F_SETFL = 4
  end

  ifdef darwin || linux
    ifdef darwin
      O_RDONLY   = 0x0000
      O_WRONLY   = 0x0001
      O_RDWR     = 0x0002
      O_APPEND   = 0x0008
      O_CREAT    = 0x0200
      O_TRUNC    = 0x0400
      O_NONBLOCK = 0x0004
    elsif linux
      O_RDONLY   = 00000000
      O_WRONLY   = 00000001
      O_RDWR     = 00000002
      O_APPEND   = 00002000
      O_CREAT    = 00000100
      O_TRUNC    = 00001000
      O_NONBLOCK = 00004000
    end

    S_IRWXU    = 0000700         # RWX mask for owner
    S_IRUSR    = 0000400         # R for owner
    S_IWUSR    = 0000200         # W for owner
    S_IXUSR    = 0000100         # X for owner
    S_IRWXG    = 0000070         # RWX mask for group
    S_IRGRP    = 0000040         # R for group
    S_IWGRP    = 0000020         # W for group
    S_IXGRP    = 0000010         # X for group
    S_IRWXO    = 0000007         # RWX mask for other
    S_IROTH    = 0000004         # R for other
    S_IWOTH    = 0000002         # W for other
    S_IXOTH    = 0000001         # X for other
  elsif windows
    O_RDONLY      = 0x0000
    O_WRONLY      = 0x0001
    O_RDWR        = 0x0002
    O_APPEND      = 0x0008
    O_CREAT       = 0x0100
    O_TRUNC       = 0x0200
    O_EXCL        = 0x0400
    O_TEXT        = 0x4000
    O_BINARY      = 0x8000
    O_WTEXT       = 0x10000
    O_U16TEXT     = 0x20000
    O_U8TEXT      = 0x40000
    O_ACCMODE     = O_RDONLY | O_WRONLY | O_RDWR
    O_RAW         = O_BINARY
    O_NOINHERIT   = 0x0080
    O_TEMPORARY   = 0x0040
    O_SHORT_LIVED = 0x1000
    O_SEQUENTIAL  = 0x0020
    O_RANDOM      = 0x0010

    S_IREAD  = 0x0100
    S_IWRITE = 0x0080
    S_IEXEC  = 0x0040
    S_IRWXU  = S_IREAD | S_IWRITE | S_IEXEC
    S_IXUSR  = S_IEXEC
    S_IWUSR  = S_IWRITE
    S_IRUSR  = S_IREAD
  end

  EWOULDBLOCK = 140
  EAGAIN      = 11

  fun getchar : Char
  fun putchar(c : Char) : Char
  fun getwchar : Char
  fun putwchar(c : Char) : Char
  fun puts(str : UInt8*) : Int32
  fun printf(str : UInt8*, ...) : Char

  ifdef darwin || linux
    fun fcntl(fd : Int32, cmd : FCNTL, ...) : Int32
    fun system(str : UInt8*) : Int32
    fun execl(path : UInt8*, arg0 : UInt8*, ...) : Int32
    fun waitpid(pid : Int32, stat_loc : Int32*, options : Int32) : Int32
    fun open(path : UInt8*, oflag : Int32, ...) : Int32
    fun dup2(fd : Int32, fd2 : Int32) : Int32
    fun read(fd : Int32, buffer : UInt8*, nbyte : LibC::SizeT) : LibC::SSizeT
    fun write(fd : Int32, buffer : UInt8*, nbyte : LibC::SizeT) : LibC::SSizeT
    fun pipe(filedes : Int32[2]*) : Int32
    fun select(nfds : Int32, readfds : Void*, writefds : Void*, errorfds : Void*, timeout : TimeVal*) : Int32

    # In fact lseek's offset is off_t, but it matches the definition of size_t
    fun lseek(fd : Int32, offset : LibC::SizeT, whence : Int32) : Int32
    fun close(fd : Int32) : Int32
    fun isatty(fd : Int32) : Int32
  elsif windows
    fun putws = _putws(str : UInt16*) : Int32
    fun wprintf = wprintf(str : UInt16*, ...) : Char
    fun wsystem = _wsystem(str : UInt16*) : Int32
    fun wexecl = _wexecl(path : UInt16*, arg0 : UInt16*, ...) : Int32
    fun wopen = _wopen(path : UInt16*, oflag : Int32, ...) : Int32
    fun dup2 = _dup2(fd : Int32, fd2 : Int32) : Int32
    fun read = _read(fd : Int32, buffer : UInt8*, nbyte : LibC::SizeT) : Int32
    fun write = _write(fd : Int32, buffer : UInt8*, nbyte : LibC::SizeT) : Int32
    fun pipe = _pipe(filedes : Int32[2]*, size : UInt32, textmode : Int32) : Int32
    fun lseek = _lseeki64(fd : Int32, offset : Int64, origin : Int32) : Int64
    fun close = _close(fd : Int32) : Int32
    fun isatty = _isatty(fd : Int32) : Int32
  end
end

module IO
  ifdef darwin || linux
    def self.select(read_ios, write_ios = nil, error_ios = nil)
      select(read_ios, write_ios, error_ios, nil).not_nil!
    end

    # Returns an array of all given IOs that are
    # * ready to read if they appeared in read_ios
    # * ready to write if they appeared in write_ios
    # * have an error condition if they appeared in error_ios
    #
    # If the optional timeout_sec is given, nil is returned if no
    # IO was ready after the specified amount of seconds passed. Fractions
    # are supported.
    #
    # If timeout_sec is nil, this method blocks until an IO is ready.
    def self.select(read_ios, write_ios, error_ios, timeout_sec : C::TimeT|Int32|Float?)
      nfds = 0
      read_ios.try &.each do |io|
        nfds = io.fd if io.fd > nfds
      end
      write_ios.try &.each do |io|
        nfds = io.fd if io.fd > nfds
      end
      error_ios.try &.each do |io|
        nfds = io.fd if io.fd > nfds
      end
      nfds += 1

      read_fdset  = FdSet.from_ios(read_ios)
      write_fdset = FdSet.from_ios(write_ios)
      error_fdset = FdSet.from_ios(error_ios)

      if timeout_sec
        sec = LibC::TimeT.cast(timeout_sec)

        if timeout_sec.is_a? Float
          usec = (timeout_sec-sec) * 10e6
        else
          usec = 0
        end

        timeout = LibC::TimeVal.new
        timeout.tv_sec = sec
        timeout.tv_usec = LibC::UsecT.cast(usec)
        timeout_ptr = pointerof(timeout)
      else
        timeout_ptr = Pointer(LibC::TimeVal).null
      end

      ret = LibC.select(nfds, read_fdset, write_fdset, error_fdset, timeout_ptr)
      case ret
      when 0 # Timeout
        nil
      when -1
        raise Errno.new("Error waiting with select()")
      else
        ios = [] of IO
        read_ios.try &.each do |io|
          ios << io if read_fdset.is_set(io)
        end
        write_ios.try &.each do |io|
          ios << io if write_fdset.is_set(io)
        end
        error_ios.try &.each do |io|
          ios << io if error_fdset.is_set(io)
        end
        ios
      end
    end
  elsif windows
    #-- TODO
  end

  # Reads count bytes from this IO into slice
  abstract def read(slice : Slice(UInt8), count)

  # Writes count bytes from slice into this IO
  abstract def write(slice : Slice(UInt8), count)

  def read(slice : Slice(UInt8))
    read slice, slice.length
  end

  def write(slice : Slice(UInt8))
    write slice, slice.length
  end

  def flush
  end

  def self.pipe
    ifdef darwin || linux
      status = LibC.pipe(out pipe_fds)
    elsif windows
      status = LibC.pipe(out pipe_fds, 4096_u32, LibC::O_BINARY)
    end
    if status != 0
      raise Errno.new("Could not create pipe")
    end

    {FileDescriptorIO.new(pipe_fds[0]), FileDescriptorIO.new(pipe_fds[1])}
  end

  def self.pipe
    r, w = IO.pipe
    begin
      yield r, w
    ensure
      r.close
      w.close
    end
  end

  def reopen(other)
    if LibC.dup2(self.fd, other.fd) == -1
      raise Errno.new("Could not reopen file descriptor")
    end

    other
  end

  # Writes the given object into this IO.
  # This ends up calling `to_s(io)` on the object.
  def <<(obj)
    obj.to_s self
    self
  end

  # Same as `<<`
  def print(obj)
    self << obj
  end

  # Writes the given string to this IO followed by a newline character
  # unless the string already ends with one.
  def puts(string : String)
    self << string
    puts unless string.ends_with?('\n')
  end

  # Writes the given object to this IO followed by a newline character.
  def puts(obj)
    self << obj
    puts
  end

  def puts
    write_byte '\n'.ord.to_u8
  end

  def read_byte
    byte :: UInt8
    if read(Slice.new(pointerof(byte), 1)) == 1
      byte
    else
      nil
    end
  end

  def read_char
    first = read_byte
    return nil unless first

    first = first.to_u32
    return first.chr if first < 0x80

    second = read_utf8_masked_byte
    return ((first & 0x1f) << 6 | second).chr if first < 0xe0

    third = read_utf8_masked_byte
    return ((first & 0x0f) << 12 | (second << 6) | third).chr if first < 0xf0

    fourth = read_utf8_masked_byte
    return ((first & 0x07) << 18 | (second << 12) | (third << 6) | fourth).chr if first < 0xf8

    raise InvalidByteSequenceError.new
  end

  private def read_utf8_masked_byte
    byte = read_byte || raise "Incomplete UTF-8 byte sequence"
    (byte & 0x3f).to_u32
  end

  def read_fully(buffer : Slice(UInt8))
    count = buffer.length
    while count > 0
      read_bytes = read(buffer, count)
      raise "Unexpected EOF" if read_bytes == 0
      count -= read_bytes
      buffer += read_bytes
    end
    count
  end

  def read
    buffer :: UInt8[2048]
    String.build do |str|
      while (read_bytes = read(buffer.to_slice)) > 0
        str.write(buffer.to_slice, read_bytes)
      end
    end
  end

  def gets
    gets '\n'
  end

  def gets(delimiter : Char)
    buffer = StringIO.new
    while true
      unless ch = read_char
        return buffer.empty? ? nil : buffer.to_s
      end

      buffer << ch
      break if ch == delimiter
    end
    buffer.to_s
  end

  def read(length)
    buffer_pointer = buffer = Slice(UInt8).new(length)
    remaining_length = length
    while remaining_length > 0
      read_length = read(buffer_pointer, remaining_length)
      if read_length == 0
        length -= remaining_length
        break
      end
      remaining_length -= read_length
      buffer_pointer += read_length
    end
    String.new(buffer[0, length])
  end

  def write(array : Array(UInt8))
    write array.buffer, array.length
  end

  def write_byte(byte : UInt8)
    x = byte
    write Slice.new(pointerof(x), 1)
  end

  def tty?
    false
  end

  def each_line
    while line = gets
      yield line
    end
  end
end

require "./io/*"

def gets
  STDIN.gets
end

def print(obj)
  STDOUT.print obj
  nil
end

def print!(obj)
  print obj
  STDOUT.flush
  nil
end

def puts(obj)
  STDOUT.puts obj
  nil
end

def puts
  STDOUT.puts
  nil
end

def p(obj)
  obj.inspect(STDOUT)
  puts
  obj
end
