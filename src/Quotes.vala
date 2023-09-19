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

public class Quote {

  private string _quote  = "";
  private string _author = "";

  /* Default constructor */
  public Quote( string quote, string author = "" ) {
    _quote  = quote;
    _author = author;
  }

  /* Constructor from XML */
  public Quote.from_xml( Xml.Node* node ) {
    load( node );
  }

  /* Returns the given quote */
  public string make_quote() {
    if( _author == "" ) {
      return( _quote );
    } else {
      return( "\"%s\" — %s".printf( _quote, _author ) );
    }
  }

  /* Saves the quote information in XML format */
  public Xml.Node* save() {
    Xml.Node* node = new Xml.Node( null, "quote" );
    node->set_prop( "author", _author );
    node->set_content( _quote );
    return( node );
  }

  /* Loads the quotation from the given node */
  public void load( Xml.Node* node ) {
    var a = node->get_prop( "author" );
    if( (a != null) && (a != "") ) {
      _author = a;
    } else {
      _author = _( "Anonymous" );
    }
    _quote = node->get_content();
  }

}

public class Quotes {

  private Array<Quote> _quotes;
  private int          _built_in_length;
  private int          _quote_index = -1;
  private string       _date        = "";

  /* Default constructor */
  public Quotes() {

    _quotes = new Array<Quote>();

    add_quote( new Quote( _( "Journal writing, when it becomes a ritual for transformation, is not only life-changing but life-expanding." ), "Jen Williamson" ) );
    add_quote( new Quote( _( "Tell me about your day." ) ) );
    add_quote( new Quote( _( "Tell me what happened today." ) ) );
    add_quote( new Quote( _( "I want to know all about what happened to you today." ) ) );
    add_quote( new Quote( _( "Sometimes the only paper will listen to you." ), "Anonymous" ) );
    add_quote( new Quote( _( "Start writing, no matter what. The water does not flow until the faucet is turned on." ), "Louis L’Amour" ) );
    add_quote( new Quote( _( "I can shake off everything as I write; my sorrows disappear, my courage is reborn." ), "Anne Frank" ) );
    add_quote( new Quote( _( "Preserve your memories, keep them well, what you forget you can never retell." ), "Louisa May Alcott" ) );
    add_quote( new Quote( _( "Write about what really interests you, whether it is real things or imaginary things, and nothing else." ), "C. S. Lewis" ) );
    add_quote( new Quote( _( "I believe myself that a good writer doesn’t really need to be told anything except to keep at it." ), "Chinua Achebe" ) );
    add_quote( new Quote( _( "Writing is medicine." ), "Julia Cameron" ) );
    add_quote( new Quote( _( "I like to reserve the right to write about whatever I like." ), "David Sedaris" ) );
    add_quote( new Quote( _( "I write because I don’t know what I think until I read what I say." ), "Flannery O’Connor" ) );
    add_quote( new Quote( _( "Journaling is like whispering to one’s self and listening at the same time." ), "Mina Murray" ) );
    add_quote( new Quote( _( "Journal writing is a voyage to the interior." ), "Christina Baldwin" ) );
    add_quote( new Quote( _( "What would you write if you weren’t afraid?" ), "Mary Karr" ) );
    add_quote( new Quote( _( "There is no greater agony than bearing an untold story inside you." ), "Maya Angelou" ) );
    add_quote( new Quote( _( "A journal is your completely unaltered voice." ), "Lucy Dacus" ) );
    add_quote( new Quote( _( "Journaling helps you to remember how strong you truly are within yourself." ), "Asad Meah" ) );
    add_quote( new Quote( _( "People who keep journals have life twice." ), "Jessamyn West" ) );
    add_quote( new Quote( _( "Journal writing gives us insights into who we are, who we were, and who we can become." ), "Sandra Marinella" ) );
    add_quote( new Quote( _( "You can always edit a bad page. You can’t edit a blank page." ), "Jodi Picoult" ) );
    add_quote( new Quote( _( "It ain’t whatcha write, it’s the way atcha write it." ), "Jack Kerouac" ) );
    add_quote( new Quote( _( "If a nation loses its storytellers, it loses its childhood." ), "Peter Handke" ) );
    add_quote( new Quote( _( "Documenting little details of your everyday life becomes a celebration of who you are." ), "Carolyn V. Hamilton" ) );
    add_quote( new Quote( _( "Turning your journal time into a mini-ritual gives it importance." ), "Julie Hage" ) );
    add_quote( new Quote( _( "Your journal is your private sanctuary, your safe haven." ), "Julie Hage" ) );

    _built_in_length = (int)_quotes.length;

    /* Load the values from the XML file */
    load();

  }

  /* Adds the given quote to the list */
  public void add_quote( Quote quote ) {
    _quotes.append_val( quote );
  }

  /* Returns a randomly selected quote */
  public string get_quote() {
    var today = DBEntry.todays_date();
    if( today != _date ) {
      _quote_index = Random.int_range( 0, (int)_quotes.length );
      _date = today;
      save();
    }
    return( _quotes.index( _quote_index ).make_quote() );
  }

  /* Returns the pathname of the XML file */
  private string xml_file() {
    return( GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler", "quotes.xml" ) );
  }

  /* Saves the current quotation and user-supplied list */
  private void save() {

    Xml.Doc*  doc  = new Xml.Doc( "1.0" );
    Xml.Node* root = new Xml.Node( null, "quotes" );

    root->set_prop( "version", Journaler.version );
    root->set_prop( "current", ((_quote_index < _built_in_length) ? "b:%d".printf( _quote_index ) : "u:%d".printf( _quote_index - _built_in_length )) );
    root->set_prop( "date",    _date );

    if( (int)_quotes.length == _built_in_length ) {
      var comment = doc->new_comment( _( "Add one or more <quote author=\"author-name\">quotation</quote> here to add quotes to the system" ) );
      root->add_child( comment );
    } else {
      for( int i=_built_in_length; i<_quotes.length; i++ ) {
        root->add_child( _quotes.index( i ).save() );
      }
    }

    doc->set_root_element( root );
    doc->save_format_file( xml_file(), 1 );

    delete doc;

  }

  /* Loads the current quotation and the user-supplied list */
  private void load() {

    Xml.Doc* doc = Xml.Parser.read_file( xml_file(), null, (Xml.ParserOption.HUGE | Xml.ParserOption.NOWARNING) );
    if( doc == null ) {
      return;
    }

    Xml.Node* root = doc->get_root_element();

    var v = root->get_prop( "version" );
    if( v != null ) {
      check_version( v );
    }

    var c = root->get_prop( "current" );
    if( c != null ) {
      string[] parts = c.split( ":" );
      if( (parts.length == 2) && ((parts[0] == "b") || (parts[0] == "u")) ) {
        _quote_index = int.parse( parts[1] ) + ((parts[0] == "u") ? _built_in_length : 0);
      }
    }

    var d = root->get_prop( "date" );
    if( d != null ) {
      _date = d;
    }

    for( Xml.Node* it = doc->get_root_element()->children; it != null; it = it->next ) {
      if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "quote") ) {
        add_quote( new Quote.from_xml( it ) ); 
      }
    }

    /* If the quote index exceeds the number of available quotes, clear the date so that we generate a random one */
    if( _quote_index >= (int)_quotes.length ) {
      _date = "";
    }

    delete doc;

  }

  /* Handles any changes between versions */
  private void check_version( string version ) {

    // TBD

  }

}
