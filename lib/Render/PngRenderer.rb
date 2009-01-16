require 'DebugLog'
require 'RMagick'
require 'Render/AbstractRenderer'
require 'tempfile'

class PngRenderer
  include AbstractRenderer
  
  def initialise_prototypes()
    @svg_renderer.initialise_prototypes()
  end

  def sugar
    @svg_renderer.sugar
  end
  
  def sugar=(sugar)
    @svg_renderer.sugar=(sugar)
  end

  def scheme=(scheme)
    @svg_renderer.scheme=(scheme)
  end

  def render(sugar)
    svg_string = @svg_renderer.render(sugar).to_s
    svg_string.gsub!(/svg\:/,'')
    svg_string.gsub!(/&#8594;/,'-')
    svg_string.gsub!(/&#945;/,'a')
    svg_string.gsub!(/&#946;/,'b')
    
    temp_svg = Tempfile.new('pngrender.svg')
    temp_svg << svg_string
    temp_svg.close
    the_svg = File.new(temp_svg.path)
    img = Magick::Image::read(the_svg) { self.format = 'SVG' }
    the_svg.close
    if ( width != nil && height != nil )
      img.first.resize_to_fit!(width,height)
    end
    return img.first.to_blob { self.format = 'PNG' }
  end

  def initialize()
    @svg_renderer = SvgRenderer.new()
    @svg_renderer.dont_use_prototypes
  end
end
