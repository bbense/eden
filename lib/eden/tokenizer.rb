module Eden
  class Tokenizer
    def initialize( source_file )
      @sf = source_file
    end
      
    def tokenize!
      @i = 0 # Current position in the source buffer
      @ln = 1 # Line Number
      @cp = 0 # Current Character in the line
      @thunk_st = 0
      @thunk_end = -1 # Start/end of the current token
      @current_line = Line.new( @ln )
      @length = @sf.source.length
      default_state_transitions!

      until( @i >= @length )
        case( @state )
        when :newline
          @current_line.tokens << Token.new( :newline, thunk )
          @sf.lines << @current_line
          @ln += 1
          @current_line = Line.new( @ln )
        when :whitespace
          @current_line.tokens << tokenize_whitespace
        when :identifier # keyword / name / etc
          @current_line.tokens << tokenize_identifier
        when :instancevar
          @current_line.tokens << tokenize_instancevar
        when :classvar
          @current_line.tokens << tokenize_classvar
        when :lparen, :rparen, :lsquare, :rsquare,
          :lcurly, :rcurly, :comma
          @current_line.tokens << tokenize_single_character
        when :plus, :minus, :equals, :modulo, :multiply, :ampersand, :pipe,
          :caret, :gt, :lt, :bang, :period, :tilde, :at, :question_mark,
          :semicolon, :equals, :colon
          @current_line.tokens << tokenize_single_character
        when :comment
        when :single_q_string 
          @current_line.tokens << tokenize_single_quote_string
        when :double_q_string
          @current_line.tokens << tokenize_double_quote_string
        when :backquote_string
          @current_line.tokens << tokenize_backquote_string
        when :symbol
          @current_line.tokens << tokenize_symbol
        when :dec_literal
          @current_line.tokens << tokenize_decimal_literal
        when :bin_literal, :oct_literal, :hex_literal
          @current_line.tokens << tokenize_integer_literal
        when :regex
        end
      end
      @sf.lines << @current_line
    end

    private
    
    def thunk
      @sf.source[[@thunk_st, @length-1].min..[@thunk_end, @length-1].min]
    end

    def default_state_transitions!
      case( cchar )
      when nil  then @state = :eof
      when ' '  then @state = :whitespace
      when '\t' then @state = :whitespace
      when '"'  then @state = :double_q_string
      when '\'' then @state = :single_q_string
      when '`'  then @state = :backquote_string
      when '@'
        if peek_ahead_for( /@/ )
          @state = :classvar
        elsif peek_ahead_for( /[A-Za-z_]/ )
          @state = :instancevar
        else 
          @state = :at
        end
      when '/'  then @state = :regex
      when '#'  then @state = :comment
      when ','  then @state = :comma
      when '.'  then @state = :period
      when '&'  then @state = :ampersand
      when '!'  then @state = :bang
      when '~'  then @state = :tilde
      when '^'  then @state = :caret
      when '|'  then @state = :pipe
      when '>'  then @state = :gt
      when '<'  then @state = :lt
      when '?'  then @state = :question_mark
      when ';'  then @state = :semicolon
      when '='  then @state = :equals
      when '%'  then @state = :modulo
      when '*'  then @state = :multiply
      when '('  then @state = :lparen
      when ')'  then @state = :rparen
      when '{'  then @state = :lcurly
      when '}'  then @state = :rcurly
      when '['  then @state = :lsquare
      when ']'  then @state = :rsquare
      when ':'
        if peek_ahead_for(/[: ]/)
          @state = :colon
        else
          @state = :symbol
        end
      when 'a'..'z', 'A'..'Z', '_'
        @state = :identifier
      when '0'
        if peek_ahead_for(/[xX]/)
          @state = :hex_literal 
        elsif peek_ahead_for(/[bB]/)
          @state = :bin_literal 
        elsif peek_ahead_for(/[_oO0-7]/)
          @state = :oct_literal
        elsif peek_ahead_for(/[89]/)
          puts "Illegal Octal Digit"
        elsif peek_ahead_for(/[dD]/)
          @state = :dec_literal
        else
          @state = :dec_literal
        end
      when '1'..'9'
        @state = :dec_literal
      when '+', '-'
        if peek_ahead_for( /[0-9]/ )
          @state = :number
        else
          @state = ( cchar == '+' ? :plus : :minus )
        end
      end
    end

    # Returns the current character
    def cchar
      @sf.source[@i..@i]
    end

    # Advance the current position in the source file
    def advance( num=1 )
      @thunk_end += num; @i += num
    end

    # Resets the thunk to start at the current character
    def reset_thunk!
      @thunk_st = @i
      @thunk_end = @i - 1
    end

    def peek_ahead_for( regex )
      @sf.source[@i+1..@i+1] && !!regex.match( @sf.source[@i+1..@i+1] )
    end

    def capture_token( type )
      token = Token.new( type, thunk )
      reset_thunk!
      default_state_transitions!
      return token
    end

    def tokenize_single_character
      @thunk_end += 1
      token = Token.new(@state, thunk)
      @i += 1
      reset_thunk!
      default_state_transitions!
      return token
    end

    def tokenize_identifier
      advance until( /[A-Za-z0-9_]/.match( cchar ).nil? )
      capture_token( @state )
    end

    def tokenize_whitespace
      advance until( cchar != ' ' && cchar != '\t' )
      capture_token( :whitespace )
    end

    def tokenize_instancevar
      advance # Pass the @ symbol
      advance until( /[a-z0-9_]/.match( cchar ).nil? )
      capture_token( :instancevar )
    end

    def tokenize_classvar
      advance(2) # Pass the @@ symbol
      advance until( /[a-z0-9_]/.match( cchar ).nil? )
      capture_token( :classvar )
    end

    def tokenize_integer_literal
      if peek_ahead_for(/[_oObBxX]/)
        advance(2) # Pass 0x / 0b / 0O
      else
        advance # Pass 0 for Octal digits
      end
      pattern = {:bin_literal => /[01]/,
                 :oct_literal => /[0-7]/,
                 :hex_literal => /[0-9a-fA-F]/}[@state]
      advance until( pattern.match( cchar ).nil? )
      capture_token( @state )
    end

    def tokenize_decimal_literal
      # Handle a lone zero
      if cchar == '0' && !peek_ahead_for(/[dD]/)
        advance
        return capture_token( :dec_literal )
      end

      # Handle 0d1234 digits
      advance(2) if cchar == '0' && peek_ahead_for(/[dD]/)

      until( /[0-9.eE]/.match( cchar ).nil? )
        case cchar
        when '.'
          return tokenize_float_literal
        when 'e', 'E'
          return tokenize_exponent_literal
        when '0'..'9'
          advance
        else
        end
      end
      capture_token( :dec_literal )
    end

    def tokenize_exponent_literal
      advance # Pass the e/E
      advance if cchar == '+' or cchar == '-'
      advance until( /[0-9]/.match( cchar ).nil? )
      capture_token( :exp_literal )
    end

    def tokenize_float_literal
      advance # Pass the .

      until( /[0-9eE]/.match( cchar ).nil? )
        if cchar == 'e' || cchar == 'E'
          return tokenize_exponent_literal
        end
        advance
      end
      capture_token( :float_literal )
    end

    def tokenize_symbol
      advance # Pass the :
      advance until( cchar == ' ' || cchar.nil? )
      capture_token( :symbol )
    end

    def tokenize_single_quote_string
      advance # Pass the opening quote
      until( cchar == '\'' || @i >= @length)
        if cchar == '\\'
          advance(2) # Pass the escaped character
        else
          advance
        end
      end
      advance # Pass the closing quote
      capture_token( @state )
    end

    def tokenize_backquote_string
      advance # Pass the opening backquote
      advance until( cchar == '`' || @i >= @length )
      advance # Pass the closing backquote
      capture_token( :backquote_string )
    end

    def tokenize_double_quote_string
      advance # Pass the opening backquote
      until( cchar == '"' || @i >= @length )
        if cchar == '\\'
          advance(2) # Pass the escaped character
        else
          advance
        end
      end
      advance # Pass the closing backquote
      capture_token( @state )
    end
  end
end
