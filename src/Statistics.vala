/*
* Copyright (c) 2023 (https://github.com/phase1geo/Journaler)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Trevor Williams <phase1geo@gmail.com>
*/

using Gtk;

public enum GoalType {
  NONE,
  CHARACTER,
  WORD,
  NUM;

  public string to_string() {
    switch( this ) {
      case NONE      :  return( "none" );
      case CHARACTER :  return( "chars" );
      case WORD      :  return( "words" );
      default        :  assert_not_reached();
    }
  }

  public string label() {
    switch( this ) {
      case NONE      :  return( _( "None" ) );
      case CHARACTER :  return( _( "Characters" ) );
      case WORD      :  return( _( "Words" ) );
      default        :  assert_not_reached();
    }
  }

  public static GoalType parse( string val ) {
    switch( val ) {
      case "none"  :  return( NONE );
      case "chars" :  return( CHARACTER );
      case "words" :  return( WORD );
      default      :  return( NONE );
    }
  }

}

public class Statistics : Box {

  private Gtk.TextBuffer _buffer;
  private Label          _label;
  private int            _chars      = 0;
  private int            _words      = 0;
  private GoalType       _goal_type  = GoalType.WORD;
  private int            _goal_count = 500;

  /* Default constructor */
  public Statistics( Gtk.TextBuffer buffer ) {

    Object( orientation: Orientation.HORIZONTAL, spacing: 5, halign: Align.FILL, hexpand: true );

    _buffer = buffer;
    _buffer.changed.connect(() => {
      calculate_statistics();
      update_stats_string();
    });

    /* Initialize the goals */
    _goal_type  = GoalType.parse( Journaler.settings.get_string( "goal-type" ) );
    _goal_count = Journaler.settings.get_int( "goal-count" );

    /* Handle any changes to the goals */
    Journaler.settings.changed["goal-type"].connect(() => {
      _goal_type = GoalType.parse( Journaler.settings.get_string( "goal-type" ) );
      update_stats_string();
    });
    Journaler.settings.changed["goal-count"].connect(() => {
      _goal_count = Journaler.settings.get_int( "goal-count" );
      update_stats_string();
    });

    _label = new Label( "" ) {
      halign     = Align.CENTER,
      hexpand    = true,
      xalign     = (float)0,
      use_markup = true
    };
    // _label.add_css_class( "text-background" );
    _label.add_css_class( "statistics-padding" );

    Idle.add(() => {
      add_css_class( "text-background" );
      return( false );
    });

    append( _label );

    /* Update the statistics string */
    update_stats_string();

  }

  /* Returns true if the character goal was reached */
  public bool goal_reached() {
    switch( _goal_type ) {
      case GoalType.NONE      :  return( false );
      case GoalType.CHARACTER :  return( _chars >= _goal_count );
      case GoalType.WORD      :  return( _words >= _goal_count );
      default                 :  return( false );
    }
  }

  /* Calculate the statistics (should be called whenever the text buffer changes) */
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

    var char_goal_str = (_goal_type == GoalType.CHARACTER) ? "  <b>( %s:  %s )</b>".printf( goal_str, ((_chars >= _goal_count) ? met_str : _goal_count.to_string()) ) : "";
    var word_goal_str = (_goal_type == GoalType.WORD)      ? "  <b>( %s:  %s )</b>".printf( goal_str, ((_words >= _goal_count) ? met_str : _goal_count.to_string()) ) : "";

    _label.label = "<b>%s:</b>  %d%s   <b>%s:</b>  %d%s".printf( char_str, _chars, char_goal_str, word_str, _words, word_goal_str );

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
