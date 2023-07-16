using Gtk;
using Enchant;

/* My implementation of gtkspell that is compatible with Gtk4 and gtksourceview-5 */
public class SpellChecker {

  private Broker broker = null;
  private unowned Dict dict;

  private TextView?    view = null;
  private GestureClick right_click;
  private TextTag?     tag_highlight = null;
  private TextMark?    mark_insert_start = null;
  private TextMark?    mark_insert_end = null;
  private TextMark?    mark_click = null;
  private bool         deferred_check = false;

  /* Default constructor */
  public SpellChecker() {
    broker = new Broker();
    right_click = new GestureClick() {
      button = 3
    };
  }

  /* Good */
  private bool text_iter_forward_word_end( ref TextIter iter ) {
    if( !iter.forward_word_end() ) {
      return( false );
    }
    if( (iter.get_char() != '\'') && (iter.get_char() != '’') ) {
      return( true );
    }
    TextIter iter2 = iter.copy();
    if( iter2.forward_char() && iter2.get_char().isalpha() ) {
      return( iter.forward_word_end() );
    }
    return( true );
  }

  /* Good */
  private bool text_iter_backward_word_start( ref TextIter iter ) {
    if( !iter.backward_word_start() ) {
      return( false );
    }
    TextIter iter2 = iter.copy();
    if( iter2.get_char().isalpha() && iter2.backward_char() && ((iter2.get_char() == '\'') || (iter2.get_char() == '’')) ) {
      return( iter.backward_word_start() );
    }
    return( true );
  }

  /* Good */
  private void check_word( TextIter start, TextIter end ) {
    var text = view.buffer.get_text( start, end, false );
    if( !text.get_char( 0 ).isdigit() && (dict.check( text ) != 0) ) {
      view.buffer.apply_tag( tag_highlight, start, end );
    }
  }

  private string iter_string( TextIter iter ) {
    return( "%d.%d".printf( iter.get_line(), iter.get_line_offset() ) );
  }

  /* Good */
  private void check_range( TextIter start, TextIter end, bool force_all ) {
    TextIter wstart, wend, cursor, precursor;
    bool inword, highlight;
    if( end.inside_word() ) {
      text_iter_forward_word_end( ref end );
    }
    if( !start.starts_word() ) {
      if( start.inside_word() || start.ends_word() ) {
        text_iter_backward_word_start( ref start );
      } else {
        if( text_iter_forward_word_end( ref start ) ) {
          text_iter_backward_word_start( ref start );
        }
      }
    }
    view.buffer.get_iter_at_mark( out cursor, view.buffer.get_insert() );
    precursor = cursor.copy();
    precursor.backward_char();
    highlight = cursor.has_tag( tag_highlight ) || precursor.has_tag( tag_highlight );
    view.buffer.remove_tag( tag_highlight, start, end );
    if( start.get_offset() == 0 ) {
      text_iter_forward_word_end( ref start );
      text_iter_backward_word_start( ref start );
    }

    wstart = start.copy();
    while( wstart.compare( end ) < 0 ) {
      wend = wstart.copy();
      text_iter_forward_word_end( ref wend );
      if( wstart.equal( wend ) ) {
        break;
      }
      inword = (wstart.compare( cursor ) < 0) && (cursor.compare( wend ) <= 0);
      if( inword && !force_all ) {
        if( highlight ) {
          check_word( wstart, wend );
        } else {
          deferred_check = true;
        }
      } else {
        check_word( wstart, wend );
        deferred_check = false;
      }
      text_iter_forward_word_end( ref wend );
      text_iter_backward_word_start( ref wend );
      if( wstart.equal( wend ) ) {
        break;
      }
      wstart = wend.copy();
    }
  }

  private void check_deferred_range( bool force_all ) {
    TextIter start, end;
    view.buffer.get_iter_at_mark( out start, mark_insert_start );
    view.buffer.get_iter_at_mark( out end,   mark_insert_end );
    check_range( start, end, force_all );
  }

  private void insert_text_before( ref TextIter iter, string text ) {
    view.buffer.move_mark( mark_insert_start, iter );
  }

  private void insert_text_after( ref TextIter iter, string text ) {
    TextIter start;
    view.buffer.get_iter_at_mark( out start, mark_insert_start );
    check_range( start, iter, false );
    view.buffer.move_mark( mark_insert_end, iter );
  }

  private void delete_range_after( TextIter start, TextIter end ) {
    check_range( start, end, false );
  }

  private void mark_set( TextIter iter, TextMark mark ) {
    if( (mark == view.buffer.get_insert()) && deferred_check ) {
      check_deferred_range( false );
    }
  }

  private void get_word_extents_from_mark( out TextIter start, out TextIter end, TextMark mark ) {
    view.buffer.get_iter_at_mark( out start, mark );
    if( !start.starts_word() ) {
      text_iter_backward_word_start( ref start );
    }
    end = start.copy();
    if( end.inside_word() ) {
      text_iter_forward_word_end( ref end );
    }
  }

  // -----------------------------------------------------------------------

  private void add_to_dictionary() {

    TextIter start, end;
    get_word_extents_from_mark( out start, out end, mark_click );

    var word = view.buffer.get_text( start, end, false );
    dict.add( word );
    recheck_all();

  }

  private void ignore_all() {

    TextIter start, end;
    get_word_extents_from_mark( out start, out end, mark_click );

    var word = view.buffer.get_text( start, end, false );
    dict.add_to_session( word );
    recheck_all();

  }

  private void replace_word( string new_word ) {

    TextIter start, end;
    get_word_extents_from_mark( out start, out end, mark_click );

    string old_word = view.buffer.get_text( start, end, false );

    view.buffer.begin_user_action();
    view.buffer.delete_range( start, end );
    view.buffer.insert_text( ref start, new_word, new_word.length );
    view.buffer.end_user_action();

    dict.store_replacement( old_word, new_word );

  }

  private void add_suggestion_menus( string word, GLib.Menu top_menu ) {

    string[] suggestions = dict.suggest( word, word.length );

    if( suggestions.length == 0 ) {
      top_menu.append( _( "No suggestions" ), "" );
    } else {
      foreach( var suggestion in suggestions ) {
        top_menu.append( suggestion, "action_replace_word('%s')".printf( suggestion ) );
      }
    }

    top_menu.append( _( "Add \"%s\" to Dictionary" ), "action_add_to_dictionary('%s')".printf( word ) );
    top_menu.append( _( "Ignore All" ), "action_ignore_all('%s')".printf( word ) );

  }

  private GLib.Menu build_suggestion_menu( string word ) {
    var top_menu = new GLib.Menu();
    add_suggestion_menus( word, top_menu );
    return( top_menu );
  }

  private void populate_popup( TextView textview, GLib.Menu menu ) {

    TextIter start, end;
    get_word_extents_from_mark( out start, out end, mark_click );

    if( !start.has_tag( tag_highlight ) ) {
      return;
    }

    var word = view.buffer.get_text( start, end, false );
    add_suggestion_menus( word, menu );

  }

  private void right_button_press_event( int n_press, double x, double y ) {
    TextIter iter;
    int buf_x, buf_y;
    if( deferred_check ) {
      check_deferred_range( true );
    }
    view.window_to_buffer_coords( TextWindowType.TEXT, (int)x, (int)y, out buf_x, out buf_y );
    view.get_iter_at_location( out iter, buf_x, buf_y );
    view.buffer.move_mark( mark_click, iter );
  }

  // Not sure if this should return bool or not yet
  private bool popup_menu_event() {
    TextIter iter;
    view.buffer.get_iter_at_mark( out iter, view.buffer.get_insert() );
    view.buffer.move_mark( mark_click, iter );
    return( false );
  }

  /* Good? */
  private void set_buffer( TextView? new_view ) {

    TextIter start, end;

    if( view != null ) {
      SignalHandler.disconnect_matched( view.buffer, SignalMatchType.DATA, 0, 0, null, null, this );
      view.buffer.get_bounds( out start, out end );
      view.buffer.remove_tag( tag_highlight, start, end );
      tag_highlight = null;

      view.buffer.delete_mark( mark_insert_start );
      view.buffer.delete_mark( mark_insert_end );
      view.buffer.delete_mark( mark_click );
      mark_insert_start = null;
      mark_insert_end   = null;
      mark_click        = null;
    }

    view = new_view;

    if( view != null ) {
      view.buffer.insert_text.connect( insert_text_before );
      view.buffer.insert_text.connect_after( insert_text_after );
      view.buffer.delete_range.connect_after( delete_range_after );
      view.buffer.mark_set.connect( mark_set );

      var tagtable = view.buffer.get_tag_table();
      tag_highlight = tagtable.lookup( "misspelled-tag" );

      if( tag_highlight == null ) {
        tag_highlight = view.buffer.create_tag( "misspelled-tag", "underline", Pango.Underline.ERROR, null );
      }

      view.buffer.get_bounds( out start, out end );
      mark_insert_start = view.buffer.create_mark( "sc-insert-start", start, true );
      mark_insert_end   = view.buffer.create_mark( "sc-insert-end",   end,   true );
      mark_click        = view.buffer.create_mark( "sc-click",        start, true );
      deferred_check    = false;
      recheck_all();
    }

  }

  private void buffer_changed( TextView new_view ) {
    if( new_view.buffer != null ) {
      set_buffer( new_view );
    } else {
      detach();
    }
  }

  private void dispose() {
    detach();
  }

  /* Good */
  public bool attach( TextView new_view ) {
    assert( view == null );
    new_view.add_controller( right_click );
    new_view.destroy.connect( detach );
    right_click.pressed.connect( right_button_press_event );
    set_buffer( new_view );
    return( true );
  }

  public void detach() {
    if( view == null ) {
      return;
    }
    view = null;
    set_buffer( null );
    deferred_check = false;
  }

  public void recheck_all() {
    TextIter start, end;
    if( view != null ) {
      view.buffer.get_bounds( out start, out end );
      check_range( start, end, true );
    }
  }

  public void ignore_word( string word ) {
    dict.add_to_session( word, word.length );
    recheck_all();
  }

  /* Good */
  public List<string> get_suggestions( string word ) {
    var list = new List<string>();
    string[] suggestions = dict.suggest( word, word.length );
    foreach( var suggestion in suggestions ) {
      list.append( suggestion );
    }
    return( list );
  }

  /* Good */
  public void get_language_list( Gee.ArrayList<string> langs ) {
    broker.list_dicts((lang_tag, provider_name, provider_desc, provider_file) => {
      langs.add( lang_tag );
    });
  }

  /* Good */
  private bool set_language_internal( string? lang ) {
    var language = lang;
    if( lang == null ) {
      language = "en";
    }
    dict = broker.request_dict( language );
    if( dict == null ) {
      return( false );
    }
    return( true );
  }

  /* Good */
  public bool set_language( string? lang ) {
    if( set_language_internal( lang ) ) {
      recheck_all();
      return( true );
    }
    return( false );
  }

}