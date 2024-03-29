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

public class Journals {

  private Array<Journal> _journals;
  private Journal        _trash;
  private Journal?       _current = null;
  private DateTime       _start_date;
  private DateTime       _end_date;

  public Journal? current {
    get {
      return( _current );
    }
    set {
      if( _current != value ) {
        if( _current != null ) {
          _current.db.purge_empty_entries();
        }
        _current = value;
        current_changed( false );
        save();
      }
    }
  }
  public Journal trash {
    get {
      return( _trash );
    }
  }

  public signal void loaded();
  public signal void current_changed( bool refresh );
  public signal void list_changed();

  /* Default constructor */
  public Journals( Templates templates ) {

    _journals   = new Array<Journal>();
    _trash      = new Journal.trash();
    _start_date = new DateTime.now_local();
    _end_date   = new DateTime.now_local();

    templates.changed.connect((name, added) => {
      if( !added ) {
        remove_template_from_journals( name );
      }
    });

  }

  /* This will select the first non-hidden journal and make it the current one */
  public void adjust_current() {
    for( int i=0; i<_journals.length; i++ ) {
      if( !_journals.index( i ).hidden ) {
        current = _journals.index( i );
      }
    }
    current = null;
  }

  /* Adds the given journal to the list of journals */
  public void add_journal( Journal journal, bool fast = false ) {
    journal.save_needed.connect( save );
    _journals.append_val( journal );
    list_changed();
    if( !fast ) {
      if( !journal.hidden ) {
        current = journal;
      }
    } else {
      save();
    }
  }

  /* Adds a default journal called "Journal" where there are no journals */
  private void add_default_journal() {
    var journal = new Journal( _( "Journal" ), "", "" );
    add_journal( journal );
  }

  /* Removes the current journal entry */
  public void remove_journal( Journal journal ) {
    for( int i=0; i<_journals.length; i++ ) {
      if( _journals.index( i ) == journal ) {
        _journals.index( i ).save_needed.disconnect( save );
        _journals.index( i ).remove_db();
        _journals.remove_index( i );
        if( _journals.length == 0 ) {
          add_default_journal();
        } else {
          if( _current == journal ) {
            current = get_journal( (i == _journals.length) ? (i - 1) : i );
          } else {
            save();
          }
          list_changed();
        }
        break;
      }
    }
  }

  /* Empties the trash */
  public bool empty_trash() {
    if( _trash.remove_db() ) {
      _trash = new Journal.trash();
      current_changed( true );
      return( true );
    }
    return( false );
  }

  /* Returns a copy of the stored start date */
  public DateTime get_start_date() {
    var date = new DateTime.local( _start_date.get_year(), _start_date.get_month(), _start_date.get_day_of_month(), 0, 0, 0 );
    return( date );
  }

  /* Returns a copy of the stored end date */
  public DateTime get_end_date() {
    var date = new DateTime.local( _end_date.get_year(), _end_date.get_month(), _end_date.get_day_of_month(), 0, 0, 0 );
    return( date );
  }

  /* Returns the number of stored journals */
  public int num_journals() {
    return( (int)_journals.length );
  }

  /* Retrieves the journal at the given index */
  public Journal get_journal( int index ) {
    return( _journals.index( index ) );
  }

  /* Retrieves the journal with the given name */
  public Journal? get_journal_by_name( string name ) {
    for( int i=0; i<_journals.length; i++ ) {
      if( _journals.index( i ).name == name ) {
        return( _journals.index( i ) );
      }
    }
    return( null );
  }

  /* Returns true if at least one journal is using the given template */
  public bool does_journal_use_template( string template ) {
    for( int i=0; i<_journals.length; i++ ) {
      if( get_journal( i ).template == template ) {
        return( true );
      }
    }
    return( false );
  }

  /* Removes the template from any journals that use it be default */
  private void remove_template_from_journals( string template ) {
    for( int i=0; i<_journals.length; i++ ) {
      if( get_journal( i ).template == template ) {
        get_journal( i ).template = "";
      }
    }
  }

  /* Purges all of the empty journal entries */
  public bool purge_empty_entries() {

    var res = true;

    for( int i=0; i<_journals.length; i++ ) {
      var journal = _journals.index( i );
      res &= journal.db.purge_empty_entries();
    }

    if( res ) {
      current_changed( true );
    }

    return( res );

  }

  /* Returns the pathname of the journals.xml file */
  private string xml_file() {
    return( GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler", "journals.xml" ) );
  }

  /* Saves the journals in XML format */
  public void save() {

    Xml.Doc*  doc  = new Xml.Doc( "1.0" );
    Xml.Node* root = new Xml.Node( null, "journals" );
    var       current_index = -1;

    root->set_prop( "version", Journaler.version );

    for( int i=0; i<_journals.length; i++ ) {
      if( _journals.index( i ) == _current ) {
        current_index = i;
      }
      root->add_child( _journals.index( i ).save() );
    }

    root->set_prop( "current",    current_index.to_string() );
    root->set_prop( "start-date", DBEntry.datetime_date( _start_date ) );

    doc->set_root_element( root );
    doc->save_format_file( xml_file(), 1 );

    delete doc;

  }

  /* Loads the journals from the XML file */
  public void load() {

    Xml.Doc* doc = Xml.Parser.read_file( xml_file(), null, (Xml.ParserOption.HUGE | Xml.ParserOption.NOWARNING) );
    if( doc == null ) {
      add_default_journal();
      return;
    }

    Xml.Node* root = doc->get_root_element();

    var v = root->get_prop( "version" );
    if( v != null ) {
      check_version( v );
    }

    var c = root->get_prop( "current" );
    var current_index = -1;
    if( c != null ) {
      current_index = int.parse( c );
    }

    var s = root->get_prop( "start-date" );
    if( s != null ) {
      _start_date = DBEntry.datetime_from_date( s );
    }

    for( Xml.Node* it = doc->get_root_element()->children; it != null; it = it->next ) {
      if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "journal") ) {
        bool loaded = false;
        var journal = new Journal.from_xml( it, out loaded );
        if( loaded ) {
          journal.save_needed.connect( save );
          _journals.append_val( journal );
        }
      }
    }

    delete doc;

    /* Set the current journal */
    if( _journals.length == 0 ) {
      add_default_journal();
    } else {
      _current = (current_index == -1) ? null : _journals.index( current_index );
    }

    current_changed( false );
    list_changed();
    loaded();

  }

  /*
   Allows us to check that the version will be compatible with the current version and
   perform any updates to make it compatible.
  */
  private void check_version( string version ) {

    // TBD

  }

}
