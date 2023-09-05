/*
* Copyright (c) 2018 (https://github.com/phase1geo/Minder)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
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

public class MarkdownFuncs {

  public static delegate void MarkdownProcessLineFunc( TextBuffer buffer, ref TextIter linestart, TextIter lineend, string text, int index );

  /*
   If text is currently selected, make sure the selection is adjusted such that the start of
   the selection is not on a whitespace character and the end selection is one character to the
   right of a non-whitespace character.
  */
  public static bool get_markup_selection( TextBuffer buffer, out TextIter start, out TextIter end ) {

    if( buffer.get_selection_bounds( out start, out end ) ) {
      if( start.get_char().isspace() ) {
        start.forward_find_char( (c) => { return( !c.isspace() ); }, null );
      }
      end.backward_char();
      if( end.get_char().isspace()  ) {
        end.backward_find_char( (c) => { return( !c.isspace() ); }, null );
      }
      end.forward_char();
      return( start.compare( end ) <= 0 );
    }

    return( false );

  }

  /* Adds the given text markup based on whether valid text is selected or not */
  public static void add_text_markup( TextBuffer buffer, string prefix, string suffix = "" ) {

    TextIter sel_start, sel_end;

    buffer.begin_user_action();

    /* Otherwise, do the text-based insertion */
    if( get_markup_selection( buffer, out sel_start, out sel_end ) ) {

      buffer.insert( ref sel_start, prefix, prefix.length );
      get_markup_selection( buffer, out sel_start, out sel_end );
      buffer.insert( ref sel_end, suffix, suffix.length );
      buffer.select_range( sel_end, sel_end );

    } else {

      TextIter cursor;

      var text = prefix + suffix;
      buffer.insert_at_cursor( text, text.length );
      buffer.get_iter_at_mark( out cursor, buffer.get_insert() );

      cursor.backward_chars( suffix.char_count() );
      buffer.place_cursor( cursor );

    }

    buffer.end_user_action();

  }

  /* Adds the line markup for each line within the selected range */
  public static void add_line_markup( TextBuffer buffer, string text, MarkdownProcessLineFunc process_line ) {

    buffer.begin_user_action();

    TextIter start, end;
    get_markup_range( buffer, true, out start, out end );
    var endrange = buffer.create_mark( "endrange", end, true );

    var index = 0;
    while( start.compare( end ) < 0 ) {
      TextIter lineend = start;
      if( !lineend.ends_line() ) {
        lineend.forward_to_line_end();
        process_line( buffer, ref start, lineend, text, index++ );
      }
      start.forward_line();
      buffer.get_iter_at_mark( out end, endrange );
    }

    buffer.select_range( start, start );

    buffer.end_user_action();

  }

  /* Inserts the given text prior to the beginning of the line if the line is not empty */
  public static void insert_line_chars( TextBuffer buffer, ref TextIter linestart, TextIter lineend, string text, int index ) {
    if( buffer.get_text( linestart, lineend, false ).strip() != "" ) {
      var ins = text.contains( "%%d" ) ? text.printf( index ) : text;
      buffer.insert( ref linestart, ins, ins.length );
    }
  }

  /*
   Inserts a line below the current line using the first character in text as the underline character.  Underline all text
   without preceding and succeeding whitespace.
  */
  public static void insert_line_below( TextBuffer buffer, ref TextIter linestart, TextIter lineend, string text, int index ) {

    TextIter cstart = linestart;

    /* Advance cstart to the first non-whitespace character */
    if( cstart.get_char().isspace() ) {
      cstart.forward_find_char( (c) => { return( !c.isspace() ); }, lineend );
    }

    var txt = buffer.get_text( cstart, lineend, false ).strip();
    if( txt != "" ) {
      var ul = buffer.get_text( linestart, cstart, false ) + string.nfill( txt.char_count(), text.get( 0 ) ) + "\n";
      linestart.forward_line();
      buffer.insert( ref linestart, ul, ul.length );
      linestart.backward_line();
    }

  }

  /*
   Gets the markup selection range depending on whether text was selected and whether we need the range
   for line-based Markdown or text-based Markdown.
  */
  public static void get_markup_range( TextBuffer buffer, bool line, out TextIter start, out TextIter end ) {

    /* Get the string to replace */
    if( buffer.get_selection_bounds( out start, out end ) ) {
      if( line ) {
        start.set_line( start.get_line() );
        end.forward_to_line_end();
      }
    } else {
      buffer.get_iter_at_mark( out start, buffer.get_insert() );
      end = start;
      start.set_line( start.get_line() );
      end.forward_to_line_end();
    }

  }

  /* Returns true if the selected text contains the given markup pattern */
  public static bool contains_markup( TextBuffer buffer, string pattern ) {

    TextIter start, end;

    get_markup_range( buffer, pattern.contains( "^" ), out start, out end );

    var text = buffer.get_text( start, end, false );

    try {
      var re = new Regex( pattern, RegexCompileFlags.MULTILINE );
      return( re.match( text ) );
    } catch( RegexError e ) {
      stderr.printf( "ERROR: %s\n", e.message );
    }

    return( false );

  }

  /* Removes any markup that matches the given regex pattern */
  public static void remove_markup( TextBuffer buffer, string pattern ) {

    TextIter start, end;

    get_markup_range( buffer, pattern.contains( "^" ), out start, out end );

    var text = buffer.get_text( start, end, false );

    try {
      var re = new Regex( pattern, RegexCompileFlags.MULTILINE );
      var new_text = re.replace_literal( text, text.length, 0, "" );
      if( new_text != text ) {
        buffer.begin_user_action();
        buffer.delete( ref start, ref end );
        buffer.insert( ref start, new_text, new_text.length );
        end = start;
        end.backward_chars( new_text.char_count() );
        buffer.select_range( start, end );
        buffer.end_user_action();
      }
    } catch( RegexError e ) {
      stderr.printf( "ERROR: %s\n", e.message );
    }

  }

  /* Adds Markdown bold syntax around selected text */
  public static void insert_bold_text( TextBuffer buffer ) {
    add_text_markup( buffer, "**", "**" );
  }

  /* Adds Markdown italic syntax around selected text */
  public static void insert_italicize_text( TextBuffer buffer ) {
    add_text_markup( buffer, "_", "_" );
  }

  /* Adds Markdown code syntax around selected text */
  public static void insert_code_text( TextBuffer buffer ) {

    TextIter start, end;

    if( buffer.get_selection_bounds( out start, out end ) && start.starts_line() && end.ends_line() ) {
      add_text_markup( buffer, "```\n", "\n```" );
    } else if( contains_markup( buffer, "`" ) ) {
      add_text_markup( buffer, "``", "``" );
    } else {
      add_text_markup( buffer, "`", "`" );
    }

  }

  /* Adds Markdown header syntax around selected text */
  public static void insert_header_text( TextBuffer buffer, int depth ) {

    var syntax = string.nfill( depth, '#' ) + " ";

    buffer.begin_user_action();
    remove_markup( buffer, "^#{1,6} " );
    add_line_markup( buffer, syntax, insert_line_chars );
    buffer.end_user_action();

  }

  /* Adds a double underline below each line of selected text, converting them to H1 headers */
  public static void insert_h1_ul_text( TextBuffer buffer ) {

    buffer.begin_user_action();
    remove_markup( buffer, "^\\s*[=-]+" );
    add_line_markup( buffer, "=", insert_line_below );
    buffer.end_user_action();

  }

  /* Adds a single underline below each line of selected text, converting them to H2 headers */
  public static void insert_h2_ul_text( TextBuffer buffer ) {

    buffer.begin_user_action();
    remove_markup( buffer, "^\\s*[=-]+" );
    add_line_markup( buffer, "-", insert_line_below );
    buffer.end_user_action();

  }

  /* Inserts ordered list numbers at the beginning of each non-empty line */
  public static void insert_ordered_list_text( TextBuffer buffer ) {

    buffer.begin_user_action();
    remove_markup( buffer, "^([-*+]|[0-9]+\\.) " );
    add_line_markup( buffer, "%d. ", insert_line_chars );
    buffer.end_user_action();

  }

  /* Inserts unordered list (-) characters at the beginning of each non-empty line */
  public static void insert_unordered_list_text( TextBuffer buffer ) {

    buffer.begin_user_action();
    remove_markup( buffer, "^([-*+]|[0-9]+\\.) " );
    add_line_markup( buffer, "* ", insert_line_chars );
    buffer.end_user_action();

  }

  /* Inserts incomplete task strings at the beginning of each non-empty line */
  public static void insert_task_text( TextBuffer buffer ) {

    buffer.begin_user_action();
    remove_markup( buffer, "\\[[ xX]\\] " );
    add_line_markup( buffer, "[ ] ", insert_line_chars );
    buffer.end_user_action();

  }

  /* Inserts incomplete task strings at the beginning of each non-empty line */
  public static void insert_task_done_text( TextBuffer buffer ) {

    buffer.begin_user_action();
    remove_markup( buffer, "\\[[ xX]\\] " );
    add_line_markup( buffer, "[x] ", insert_line_chars );
    buffer.end_user_action();

  }

  /* Removes all markup from the selected area */
  public static void clear_markup( TextBuffer buffer ) {

    /* Remove the markup */
    remove_markup( buffer, "(^#+\\s+|`+|\\*+|_{1,2}|^-\\s+|^[0-9]+\\.\\s+|\\[[ xX]\\]\\s+|^\\s*[=-]+)" );

    /* Deselect text */
    TextIter cursor;
    buffer.get_iter_at_mark( out cursor, buffer.get_insert() );
    buffer.select_range( cursor, cursor );

  }

}

