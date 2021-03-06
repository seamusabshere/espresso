# Inter-Process Cache Manager
class EspressoApp
  
  def ipcm_trigger *args
    if pids_reader
      pids = pids_reader.call rescue nil
      if pids.is_a?(Array)
        pids.map(&:to_i).reject {|p| p < 2 || p == Process.pid }.each do |pid|
          file = '%s/%s.%s-%s' % [ipcm_tmpdir, pid, args.hash, Time.now.to_f]
          begin
            File.open(file, 'w') {|f| f << Marshal.dump(args)}
            Process.kill ipcm_signal, pid
          rescue => e
            warn "was unable to perform IPCM operation because of error: %s" % ::CGI.escapeHTML(e.message)
            File.unlink(file) if File.file?(file)
          end
        end
      else
        warn "pids_reader should return an array of pids. Exiting IPCM..."
      end
    end
  end

  def ipcm_tmpdir path = nil
    return @ipcm_tmpdir if @ipcm_tmpdir
    if path
      @ipcm_tmpdir = ((path =~ /\A\// ? path : root + path) + '/').freeze
    else
      @ipcm_tmpdir = (root + 'tmp/ipcm/').freeze
    end
    FileUtils.mkdir_p @ipcm_tmpdir
    @ipcm_tmpdir
  end

  def ipcm_signal signal = nil
    return @ipcm_signal if @ipcm_signal
    @ipcm_signal = signal.to_s if signal
    @ipcm_signal ||= 'ALRM'
  end

  def register_ipcm_signal
    Signal.trap ipcm_signal do
      Dir[ipcm_tmpdir + '%s.*' % Process.pid].each do |file|
        unless (setup = Marshal.restore(File.read(file)) rescue nil).is_a?(Array)
          warn "Was unable to process \"%s\" cache file, skipping cache cleaning" % file
        end
        File.unlink(file) if File.file?(file)
        meth = setup.shift
        [ :clear_cache,
          :clear_cache_like,
          :clear_compiler,
          :clear_compiler_like,
        ].include?(meth) && self.send(meth, *setup)
      end
    end
  end

  def pids_reader &proc
    return @pids_reader if @pids_reader
    if proc.is_a?(Proc)
      @pids_reader = proc
      register_ipcm_signal
    end
  end
  alias pids pids_reader

end
