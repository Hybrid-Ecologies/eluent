class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  def home
  end
  private
  def get_videos
    files = Dir.glob("public/videos/*").collect!{|c| c.split('/')[2..-1].join('/')}
    return files
  end
  def get_sounds
    files = Dir.glob("public/audio/*.wav").collect!{|c| c.split('/')[2..-1].join('/')[0..-5]}
    return files
  end
  def get_all_sounds
    files = Dir.glob("public/all_audio/*.wav").collect!{|c| c.split('/')[2..-1].join('/')[0..-5]}
    return files
  end
end
