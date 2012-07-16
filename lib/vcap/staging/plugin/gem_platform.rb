class GemPlatform

  attr_accessor :name

  def initialize(name)
    @name = name
  end

  def current_platform?(ruby_version=RUBY_VERSION)
    @ruby_version = ruby_version
    send("#{@name}?")
  end

  private

  def ruby?
    !mswin? && (!defined?(RUBY_ENGINE) || RUBY_ENGINE == "ruby" || RUBY_ENGINE == "rbx" || RUBY_ENGINE == "maglev")
  end

  def ruby_18?
    ruby? && @ruby_version < "1.9"
  end

  def ruby_19?
    ruby? && @ruby_version >= "1.9" && @ruby_version < "2.0"
  end

  def mri?
    !mswin? && (!defined?(RUBY_ENGINE) || RUBY_ENGINE == "ruby")
  end

  def mri_18?
    mri? && @ruby_version < "1.9"
  end

  def mri_19?
    mri? && @ruby_version >= "1.9" && @ruby_version < "2.0"
  end

  def rbx?
    ruby? && defined?(RUBY_ENGINE) && RUBY_ENGINE == "rbx"
  end

  def jruby?
    defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
  end

  def maglev?
    defined?(RUBY_ENGINE) && RUBY_ENGINE == "maglev"
  end

  def mswin?
    Bundler::WINDOWS
  end

  def mingw?
    Bundler::WINDOWS && Gem::Platform.local.os == "mingw32"
  end

  def mingw_18?
    mingw? && @ruby_version < "1.9"
  end

  def mingw_19?
    mingw? && @ruby_version >= "1.9"
  end
end
