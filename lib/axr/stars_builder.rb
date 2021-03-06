module AjaxfulRating # :nodoc:
  class StarsBuilder # :nodoc:
    include AjaxfulRating::Locale

    attr_reader :rateable, :user, :options

    def initialize(rateable, user_or_static, template, css_builder, options = {})
      @user = user_or_static unless user_or_static == :static
      @rateable, @template, @css_builder = rateable, template, css_builder
      apply_stars_builder_options!(options)
    end

    def show_value
      if options[:show_user_rating]
        rate = rateable.rate_by(user, options[:dimension]) if user
        rate ? rate.stars : 0
      else
        rateable.rate_average(true, options[:dimension])
      end
    end

    def render
      options[:wrap] ? wrapper_tag : ratings_tag
    end

    private

    def apply_stars_builder_options!(options)
      @options = {
        :url => nil,
        :method => :post,
        :wrap => true,
        :size => nil,
        :show_user_rating => false,
        :force_static => false,
        :current_user => (@template.current_user if @template.respond_to?(:current_user))
      }.merge(options)

      @options[:show_user_rating] = @options[:show_user_rating].to_s == 'true'
      @options[:wrap] = @options[:wrap].to_s == 'true'

      if @options[:url].nil?
        rateable_name = ActionController::RecordIdentifier.dom_class(rateable)
        url = "rate_#{rateable_name}_path"
        if @template.respond_to?(url)
          @options[:url] = @template.send(url, rateable)
        else
          raise(Errors::MissingRateRoute)
        end
      end
    end

    def ratings_tag
      stars = []
      li_width = (show_value / rateable.class.max_stars.to_f) * 100
      li_class = "axr-#{show_value}-#{rateable.class.max_stars}".gsub('.', '_')
      # Has to happen dynamically to allow for different number of stars
      # Remember to change 10, 18 & 25 to match the width of your images if you change them
      css_width = case options[:size]
      when :small
        (rateable.class.max_stars * 10)
      when :medium
        (rateable.class.max_stars * 18)
      else
        (rateable.class.max_stars * 25)
      end
      @css_builder.rule('.ajaxful-rating', :width => css_width)
      @css_builder.rule(".ajaxful-rating.#{options[:size].to_s}", :width => css_width) if options[:size]

      stars << @template.content_tag(:li, i18n(:current), :class => "show-value",
        :style => "width: #{li_width}%")
      stars += (1..rateable.class.max_stars).map do |i|
        star_tag(i)
      end
      # When using rails_xss plugin, it needs to render as HTML
      @template.content_tag(:ul, stars.join.try(:html_safe), :class => "ajaxful-rating #{options[:size].to_s}")
    end

    def star_tag(value)
      already_rated = rateable.rated_by?(user, options[:dimension]) if user && !rateable.axr_config(options[:dimension])[:allow_update]
      css_class = "stars-#{value}"
      @css_builder.rule(".ajaxful-rating .#{css_class}", {
        :width => "#{(value / rateable.class.max_stars.to_f) * 100}%",
        :zIndex => (rateable.class.max_stars + 2 - value).to_s
      })
      @template.content_tag(:li) do
        if !options[:force_static] && (user && options[:current_user] == user &&
          (!already_rated || rateable.axr_config[:allow_update]))
          link_star_tag(value, css_class)
        else
          @template.content_tag(:span, show_value, :class => css_class, :title => i18n(:current))
        end
      end
    end

    def link_star_tag(value, css_class)
      html = {
        :"data-url" => options[:url],
        :"data-method" => options[:method],
        :"data-stars" => value,
        :"data-dimension" => options[:dimension],
        :"data-size" => options[:size].to_s,
        :"data-show_user_rating" => options[:show_user_rating],
        :class => css_class,
        :title => i18n(:hover, value)
      }

      options = {
        :class => css_class,
        :title => i18n(:hover, value),
        :method => :post,
        :remote => true
      }

      @template.link_to(value, "#", html)
    end

    def wrapper_tag
      @template.content_tag(:div, ratings_tag, :class => "ajaxful-rating-wrapper",
        :id => rateable.wrapper_dom_id(options))
    end
  end
end
