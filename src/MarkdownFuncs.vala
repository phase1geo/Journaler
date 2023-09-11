/*
* Copyright (c) 2023 (https://github.com/phase1geo/Journaler)
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

  /* Returns the directory containing the templates.snippets file */
  private static string xml_dir() {
    return( GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler" ) );
  }

  /* Add the markdown.snippets file to the user's directory */
  public static void add_markdown_snippets() {

    var path = GLib.Path.build_filename( xml_dir(), "markdown.snippets" );

    /* If the file already exists, leave it alone */
    if( FileUtils.test( path, FileTest.EXISTS ) ) {
      return;
    }

    var contents = """
      <?xml version="1.0"?>
      <snippets _group="journaler-markdown">
        <snippet _name="md-bold" _description="Insert bold text" trigger="%md-bold%">
          <text languages="markdown"><![CDATA[**${1}**$0]]></text>
        </snippet>
        <snippet _name="md-italic" _description="Insert italicized text" trigger="%md-italic%">
          <text languages="markdown"><![CDATA[_${1}_$0]]></text>
        </snippet>
        <snippet _name="md-monospace" _description="Insert monospaced text" trigger="%md-mono%">
          <text languages="markdown"><![CDATA[`${1}`$0]]></text>
        </snippet>
        <snippet _name="md-link" _description="Insert link text" trigger="%md-link%">
          <tooltip position="1" text="Linked text goes here"/>
          <tooltip position="2" text="Link URL goes here"/>
          <text languages="markdown"><![CDATA[[${1:text}](${2:uri})$0]]></text>
        </snippet>
        <snippet _name="md-image" _description="Insert image text" trigger="%md-image%">
          <tooltip position="1" text="Alternate text goes here"/>
          <tooltip position="2" text="Image URL goes here"/>
          <text languages="markdown"><![CDATA[![${1:text}](${2:uri})$0]]></text>
        </snippet>
      </snippets>
      """;

    try {
      FileUtils.set_contents( path, contents );
    } catch( FileError e ) {
      stderr.printf( "ERROR: %s\n", e.message );
    }

  }

  /* Returns the snippet associated with the given template name */
  public static GtkSource.Snippet? get_snippet( string trigger ) {

    /* Add the snippets file if it doesn't exist */
    add_markdown_snippets();

    /* Get the snippet manager */
    var mgr = GtkSource.SnippetManager.get_default();
    var search_path = mgr.search_path;
    search_path += xml_dir();
    mgr.search_path = search_path;

    var snippet = mgr.get_snippet( "journaler-markdown", null, trigger );

    /* We need to remove the tooltips because there appears to be a bug */
    if( snippet != null ) {
      for( int i=0; i<snippet.get_n_chunks(); i++ ) {
        snippet.get_nth_chunk( i ).set_tooltip_text( "" );
      }
    }

    return( snippet );

  }

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
  public static void add_text_markup( GtkSource.View view, TextBuffer buffer, string prefix, string suffix = "", string trigger = "" ) {

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
      buffer.get_iter_at_mark( out cursor, buffer.get_insert() );

      var snippet = get_snippet( trigger );
      if( snippet != null ) {
        view.push_snippet( snippet, ref cursor );
      } else {
        var text = prefix + suffix;
        buffer.insert( ref cursor, text, text.length );
        cursor.backward_chars( suffix.char_count() );
        buffer.place_cursor( cursor );
      }

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
    while( ((index == 0) && (start.compare( end ) == 0)) || (start.compare( end ) < 0) ) {
      TextIter lineend = start;
      if( !lineend.ends_line() ) {
        lineend.forward_to_line_end();
      }
      process_line( buffer, ref start, lineend, text, index++ );
      start.forward_line();
      buffer.get_iter_at_mark( out end, endrange );
    }

    buffer.select_range( start, start );

    buffer.end_user_action();

  }

  /* Inserts the given text at the beginning of each empty line that contains a non-empty line below it */
  public static void insert_at_empty_line( TextBuffer buffer, ref TextIter linestart, TextIter lineend, string text, int index ) {
    if( buffer.get_text( linestart, lineend, false ).strip() == "" ) {
      var next_linestart = linestart;
      next_linestart.forward_line();
      if( linestart.compare( next_linestart ) == 0 ) {
        buffer.insert( ref linestart, text, text.length );
      } else {
        var next_lineend = next_linestart;
        if( !next_lineend.ends_line() ) {
          next_lineend.forward_to_line_end();
          if( buffer.get_text( next_linestart, next_lineend, false ).strip() != "" ) {
            buffer.insert( ref linestart, text, text.length );
          }
        }
      }
    }
  }

  /* Inserts the given text prior to the beginning of the line if the line is not empty */
  public static void insert_line_chars( TextBuffer buffer, ref TextIter linestart, TextIter lineend, string text, int index ) {
    if( buffer.get_text( linestart, lineend, false ).strip() != "" ) {
      var ins = text.contains( "%d" ) ? text.printf( index + 1 ) : text;
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
      var new_text = re.replace_eval( text, text.length, 0, 0, (mi, res) => {
        int start_pos, end_pos;
        if( mi.fetch_pos( 1, out start_pos, out end_pos ) ) {
          TextIter fstart = start;
          TextIter fend   = start;
          fstart.forward_chars( text.char_count( start_pos ) );
          fend.forward_chars( text.char_count( end_pos ) );
          if( fstart.starts_line() && fend.ends_line() ) {
            res.erase( (res.len - 1), 1 );
          }
        }
        for( int i=2; i<mi.get_match_count(); i++ ) {
          var str = mi.fetch( i );
          if( str != null ) {
            res = res.append( str + ((i == 2) ? " " : "") );
          }
        }
        return( false );
      });
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
  public static void insert_bold_text( GtkSource.View view, TextBuffer buffer ) {
    add_text_markup( view, buffer, "**", "**", "%md-bold%" );
  }

  /* Adds Markdown italic syntax around selected text */
  public static void insert_italicize_text( GtkSource.View view, TextBuffer buffer ) {
    add_text_markup( view, buffer, "_", "_", "%md-italic%" );
  }

  /* Adds Markdown code syntax around selected text */
  public static void insert_code_text( GtkSource.View view, TextBuffer buffer ) {

    TextIter start, end;

    if( buffer.get_selection_bounds( out start, out end ) && start.starts_line() && end.ends_line() ) {
      add_text_markup( view, buffer, "```\n", "\n```" );
    } else if( contains_markup( buffer, "`" ) ) {
      add_text_markup( view, buffer, "``", "``" );
    } else {
      add_text_markup( view, buffer, "`", "`", "%md-mono%" );
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

  /* Inserts a horizontal rule */
  public static void insert_horizontal_rule( TextBuffer buffer ) {

    var syntax = "---\n";

    buffer.begin_user_action();
    add_line_markup( buffer, syntax, insert_at_empty_line );
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

  /* Inserts a link */
  public static void insert_link_text( GtkSource.View view, TextBuffer buffer ) {

    TextIter start, end;

    if( buffer.get_selection_bounds( out start, out end ) ) {

      var selected = buffer.get_text( start, end, false );

      try {
        if( Uri.is_valid( selected, UriFlags.NONE ) ) {
          var text = "[](" + selected + ")";
          buffer.begin_user_action();
          buffer.delete( ref start, ref end );
          buffer.insert( ref start, text, text.length );
          start.backward_chars( text.char_count() - 1 );
          buffer.place_cursor( start );
          buffer.end_user_action();
          return;
        }
      } catch( Error e ) {}

      var text = "[" + selected + "]()";
      buffer.begin_user_action();
      buffer.delete( ref start, ref end );
      buffer.insert( ref start, text, text.length );
      start.backward_char();
      buffer.place_cursor( start ); 
      buffer.end_user_action();

    } else {

      TextIter cursor;
      buffer.get_iter_at_mark( out cursor, buffer.get_insert() );

      var snippet = get_snippet( "%md-link%" );
      if( snippet != null ) {
        view.push_snippet( snippet, ref cursor );
      }

    }

  }

  /* Inserts a link */
  public static void insert_image_text( GtkSource.View view, TextBuffer buffer, ImageArea imager ) {

    TextIter start, end;

    if( buffer.get_selection_bounds( out start, out end ) ) {

      var selected = buffer.get_text( start, end, false );

      try {
        if( Uri.is_valid( selected, UriFlags.NONE ) && imager.is_uri_supported_image( selected ) ) {
          var text = "![](" + selected + ")";
          buffer.begin_user_action();
          buffer.delete( ref start, ref end );
          buffer.insert( ref start, text, text.length );
          start.backward_chars( text.char_count() - 2 );
          buffer.place_cursor( start );
          buffer.end_user_action();
          return;
        }
      } catch( Error e ) {}

      var text = "![" + selected + "]()";
      buffer.begin_user_action();
      buffer.delete( ref start, ref end );
      buffer.insert( ref start, text, text.length );
      start.backward_char();
      buffer.place_cursor( start ); 
      buffer.end_user_action();

    } else {

      TextIter cursor;
      buffer.get_iter_at_mark( out cursor, buffer.get_insert() );

      var snippet = get_snippet( "%md-image%" );
      if( snippet != null ) {
        view.push_snippet( snippet, ref cursor );
      }

    }

  }

  /* Removes all markup from the selected area */
  public static void clear_markup( TextBuffer buffer ) {

    /* Remove the markup */
    remove_markup( buffer, "(^#+\\s+|`+|\\*+|_{1,2}|^-\\s+|^[0-9]+\\.\\s+|\\[[ xX]\\]\\s+|^\\s*[=-]+|!?\\[(.*?)\\]\\s*\\((.*?)\\))" );

    /* Deselect text */
    TextIter cursor;
    buffer.get_iter_at_mark( out cursor, buffer.get_insert() );
    buffer.select_range( cursor, cursor );

  }

}

