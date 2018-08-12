class Jekyll::Tags::HighlightBlock
    old_sanitized_opts = instance_method(:sanitized_opts)
  
    define_method(:sanitized_opts) do |*args|
      old_sanitized_opts.bind(self).(*args).
        merge(Jekyll.configuration.fetch("pygments_options", {}))
    end
  end