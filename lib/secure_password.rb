class SecurePassword
  require 'set'
  
  CHARS_BY_TYPE = {
    lower: ('a'..'z').to_a.freeze,
    upper: ('A'..'Z').to_a.freeze,
    digit: ('0'..'9').to_a.freeze,
    special_chars: %w(@ $ % &).freeze
  }.freeze

  ALL = (CHARS_BY_TYPE[:lower] + CHARS_BY_TYPE[:upper] + CHARS_BY_TYPE[:digit] + CHARS_BY_TYPE[:special_chars]).freeze

  class << self
    def generate(len)
      return if Rails.env.test?
      
      raise ArgumentError if len < 4
      s = (len - 3).times.with_object('') { |_,s| s << append_random_char(s[-1]) }
      types_to_add(s).each { |type| insert_in_password(s, CHARS_BY_TYPE[type].sample) }
      (len - s.size).times { s << append_random_char(s[-1]) }
      s
    end

    def append_random_char(last_char)
      loop do
        ch = ALL.sample
        break ch unless ch == last_char
      end
    end
    
    def types_to_add(str)
      [:lower, :upper, :digit, :special_chars].select do |type|
        st = CHARS_BY_TYPE[type].to_set
        str.each_char.none? { |ch| st.include?(ch) }
      end
    end

    def insert_in_password(str, ch)
      i = loop do
        i = rand(str.size + 1)
        next if ch == str[i]
        break i if i.zero? || ch != str[i-1]
      end
      str.insert(i, ch)
    end
  end
end
