using Gtk;

public class Statistics : Box {

  private Gtk.TextBuffer _buffer;
  private Label          _label;
  private int            _chars      = 0;
  private int            _words      = 0;
  private int            _chars_goal = 1000;
  private int            _words_goal = 500; 

  /* Default constructor */
  public Statistics( Gtk.TextBuffer buffer ) {

    Object( orientation: Orientation.HORIZONTAL, spacing: 5 );

    _buffer = buffer;
    _buffer.changed.connect(() => {
      calculate_statistics();
      update_stats_string();
    });

    /* Initialize the goals */
    _chars_goal = Journaler.settings.get_int( "character-goal" );
    _words_goal = Journaler.settings.get_int( "word-goal" );

    /* Handle any changes to the goals */
    Journaler.settings.changed["character-goal"].connect(() => {
      _chars_goal = Journaler.settings.get_int( "character-goal" );
      update_stats_string();
    });
    Journaler.settings.changed["word-goal"].connect(() => {
      _words_goal = Journaler.settings.get_int( "word-goal" );
      update_stats_string();
    });

    _label = new Label( "" ) {
      halign     = Align.FILL,
      hexpand    = true,
      xalign     = (float)0,
      use_markup = true
    };
    _label.add_css_class( "text-background" );
    _label.add_css_class( "statistics-padding" );

    append( _label );

    /* Update the statistics string */
    update_stats_string();

  }

  /* Returns true if the character goal was reached */
  public bool character_goal_reached() {
    return( _chars >= _chars_goal );
  }

  /* Returns true if the word goal was reached */
  public bool word_goal_reached() {
    return( _words >= _words_goal );
  }

  /* Calculate the statistics (should be called whenver the text buffer changes) */
  private void calculate_statistics() {
    _chars = _buffer.text.char_count();
    _words = calculate_word_count( _buffer.text );
  }

  /* Updates the statistics label based on the current buffer */
  private void update_stats_string() {
    
    var char_str = _( "Characters" );
    var word_str = _( "Words" );
    var goal_str = _( "Goal" );
    var met_str  = _( "Achieved" );

    _label.label = _( "<b>%s:</b>  %d  <b>( %s:  %s )   %s:</b>  %d  <b>( %s:  %s )</b>" ).printf(
      char_str, _chars, goal_str, ((_chars >= _chars_goal) ? met_str : _chars_goal.to_string()),
      word_str, _words, goal_str, ((_words >= _words_goal) ? met_str : _words_goal.to_string())
    );

  }

  /* Returns the number of words in the document */
  private int calculate_word_count( string text ) {

    var possible_words = text.replace( "\t", " " ).replace( "\n", " " ).split( " " );
    var words = 0;

    foreach( var word in possible_words ) {
      if( word.strip() != "" ) {
        words++;
      }
    }

    return( words );

  }

}
