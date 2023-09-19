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

public class DateCalculator {

  /* Constructor */
  public DateCalculator() {}

  /* Returns true if the calculator is absolute */
  public virtual bool is_absolute() {
    return( true );
  }

  /* Returns the name associated with the date */
  public virtual string get_name( bool start, bool other_abs ) {
    return( "" );
  }

  /* Returns the calculated date */
  public virtual DateTime get_date( DateTime dt ) {
    return( dt );
  }

  public string xml_node_name( bool start ) {
    if( start ) {
      return( is_absolute() ? "absolute-start-date" : "relative-start-date" );
    } else {
      return( is_absolute() ? "absolute-end-date" : "relative-end-date" );
    }
  }

  public virtual Xml.Node* save( bool start ) {
    Xml.Node* node = new Xml.Node( null, xml_node_name( start ) );
    return( node );
  }

  public virtual void load( Xml.Node* node ) {}

}

public class AbsoluteDate : DateCalculator {

  private DateTime _date;

  /* Default constructor */
  public AbsoluteDate( DateTime dt ) {
    _date = new DateTime.local( dt.get_year(), dt.get_month(), dt.get_day_of_month(), 0, 0, 0 );
  }

  /* Constructor from XML */
  public AbsoluteDate.from_xml( Xml.Node* node ) {
    load( node );
  }

  /* Returns true */
  public override bool is_absolute() {
    return( true );
  }

  public override string get_name( bool start, bool other_abs ) {
    if( start ) {
      return( _( " from %s to" ).printf( DBEntry.datetime_date( _date ) ) );
    } else {
      return( " %s".printf( DBEntry.datetime_date( _date ) ) );
    }
  }

  public override DateTime get_date( DateTime dt ) {
    return( _date );
  }

  public override Xml.Node* save( bool start ) {
    Xml.Node* node = base.save( start );
    node->set_prop( "date", DBEntry.datetime_date( _date ) );
    return( node );
  }

  public override void load( Xml.Node* node ) {
    base.load( node );
    var d = node->get_prop( "date" );
    if( d != null ) {
      var entry = new DBEntry();
      entry.date = d;
      _date = entry.datetime();
    }
  }

}

public class RelativeDate : DateCalculator {

  public enum RelativeDateType {
    NONE,
    CURRENT,
    DAYS,
    MONTHS,
    YEARS,
    NUM;

    public string to_string() {
      switch( this ) {
        case NONE    :  return( "none" );
        case CURRENT :  return( "current" );
        case DAYS    :  return( "days" );
        case MONTHS  :  return( "months" );
        case YEARS   :  return( "years" );
        default      :  assert_not_reached();
      }
    }

    public string label( int num ) {
      switch( this ) {
        case NONE    :  return( "" );
        case CURRENT :  return( _( "today" ) );
        case DAYS    :  return( (num == 1) ? _( "day" )   : _( "days" ) );
        case MONTHS  :  return( (num == 1) ? _( "month" ) : _( "months" ) );
        case YEARS   :  return( (num == 1) ? _( "year" )  : _( "years" ) );
        default      :  assert_not_reached();
      }
    }

    public static RelativeDateType parse( string val ) {
      switch( val ) {
        case "none"    :  return( NONE );
        case "current" :  return( CURRENT );
        case "days"    :  return( DAYS );
        case "months"  :  return( MONTHS );
        case "years"   :  return( YEARS );
        default        :  assert_not_reached();
      }
    }

  }

  private int              _num  = 0;
  private RelativeDateType _type = RelativeDateType.NONE;

  /*
   Default constructor

   Stored a relative date based on the distance between date and the current date.  It is
   required that current is newer than date.
  */
  public RelativeDate( DateTime current, DateTime date ) {

    int[] eom = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};

    /* Check to see if the year is the only difference */
    if( (current.get_month() == date.get_month()) && (current.get_day_of_month() == date.get_day_of_month()) ) {
      _num  = current.get_year() - date.get_year();
      _type = RelativeDateType.YEARS;

      /* Special case if the start and end date are the same, change the num and period to the last day */
      if( _num == 0 ) {
        _type = RelativeDateType.CURRENT;
      }

    /* Check to see if the month is the main difference */
    } else if( (current.get_day_of_month() == date.get_day_of_month()) ||
               ((eom[current.get_month()-1] <= current.get_day_of_month()) && (eom[date.get_month()-1] <= date.get_day_of_month())) ) {
      var year_diff = current.get_year() - date.get_year();
      if( current.get_month() > date.get_month() ) {
        _num = (current.get_month() - date.get_month()) + (year_diff * 12);
      } else {
        _num = (12 - date.get_month()) + current.get_month() + ((year_diff - 1) * 12);
      }
      _type = RelativeDateType.MONTHS;

    /* Otherwise, just figure out the day difference */
    } else {
      var span = current.difference( date );
      _num  = (int)(span / TimeSpan.DAY);
      _type = RelativeDateType.DAYS;
    }

  }

  /* Constructor from XML */
  public RelativeDate.from_xml( Xml.Node* node ) {
    load( node );
  }

  /* Returns false */
  public override bool is_absolute() {
    return( false );
  }

  /* Returns the relative name string */
  public override string get_name( bool start, bool other_abs ) {
    if( start ) {
      if( _type == RelativeDateType.CURRENT ) {
        return( "" );
      } else {
        return( _( " %d %s before" ).printf( _num, _type.label( _num ) ) );
      }
    } else { 
      if( _type == RelativeDateType.CURRENT ) {
        return( " %s".printf( _type.label( _num ) ) );
      } else {
        return( _( " %d %s ago" ).printf( _num, _type.label( _num ) ) );
      }
    }
  }

  /* Returns the date relative to the input date */
  public override DateTime get_date( DateTime dt ) {
    var new_date = new DateTime.local( dt.get_year(), dt.get_month(), dt.get_day_of_month(), 0, 0, 0 );
    switch( _type ) {
      case RelativeDateType.DAYS   :  new_date = new_date.add_days( 0 - _num );    break;
      case RelativeDateType.MONTHS :  new_date = new_date.add_months( 0 - _num );  break;
      case RelativeDateType.YEARS  :  new_date = new_date.add_years( 0 - _num );   break;
      default                      :  break;
    }
    return( new_date );
  }

  public override Xml.Node* save( bool start ) {
    Xml.Node* node = base.save( start );
    node->set_prop( "num", _num.to_string() );
    node->set_prop( "type", _type.to_string() );
    return( node );
  }

  public override void load( Xml.Node* node ) {
    base.load( node );
    var n = node->get_prop( "num" );
    if( n != null ) {
      _num = int.parse( n );
    }
    var t = node->get_prop( "type" );
    if( t != null ) {
      _type = RelativeDateType.parse( t );
    }
  }

}

public class SavedReview {

  private string         _name;
  private List<string>   _journals;
  private bool           _all_journals;
  private List<string>   _tags;
  private bool           _all_tags;
  private DateCalculator _start_date;
  private DateCalculator _end_date;
  private string         _search_str;

  public string name {
    get {
      return( _name );
    }
    set {
      _name = value;
    }
  }
  public bool all_journals {
    get {
      return( _all_journals );
    }
  }
  public List<string> journals {
    get {
      return( _journals );
    }
  }
  public bool all_tags {
    get {
      return( _all_tags );
    }
  }
  public List<string> tags {
    get {
      return( _tags );
    }
  }
  public string search_str {
    get {
      return( _search_str );
    }
  }

  /* Default Constructor */
  public SavedReview( List<string> journals, int num_journals, List<string> tags, int num_tags, DateTime start_date, bool start_abs, DateTime end_date, bool end_abs, string search_str ) {

    /* Store the journal names */
    _journals     = new List<string>();
    _all_journals = (journals.length() == num_journals);
    foreach( var journal in journals ) {
      _journals.append( journal );
    }

    /* Store the tag names */
    _tags     = new List<string>();
    _all_tags = (tags.length() == num_tags);
    foreach( var tag in tags ) {
      _tags.append( tag );
    }

    /* Store the end date */
    if( end_abs ) {
      _end_date = new AbsoluteDate( end_date );
    } else {
      _end_date = new RelativeDate( new DateTime.now_local(), end_date );
    }

    /* Store the start date */
    if( start_abs ) {
      _start_date = new AbsoluteDate( start_date );
    } else {
      _start_date = new RelativeDate( end_date, start_date );
    }

    /* Store the search term */
    _search_str = search_str;

    /* Creates the name based on the stored information */
    _name = create_name( num_journals, num_tags );

  }

  /* Constructor from XML */
  public SavedReview.from_xml( Xml.Node* node ) {

    _journals = new List<string>();
    _tags     = new List<string>();

    load( node );

  }

  /* Creates the given name */
  private string create_name( int num_journals, int num_tags ) {
    var search_str = (_search_str == "") ? "" : ", %s".printf( _search_str );
    return( Reviewer.make_menubutton_label( _journals, num_journals, _( "All journals" ), _( "No journals" ) ) + ", " +
            Reviewer.make_menubutton_label( _tags, num_tags, _( "All tags" ), _( "No tags" ) ) + ", " +
            create_name_date_range() +
            search_str );
  }

  private string create_name_date_range() {
    return( _start_date.get_name( true, _end_date.is_absolute() ) + _end_date.get_name( false, _start_date.is_absolute() ) );
  }

  /* Returns the start date to use for the review */
  public DateTime get_start_date() {
    return( _start_date.get_date( get_end_date() ) );
  }

  /* Returns the end date to use for the review */
  public DateTime get_end_date() {
    var now = new DateTime.now_local();
    return( _end_date.get_date( now ) );
  }

  /* Saves the review in XML format */
  public Xml.Node* save() {

    Xml.Node* node   = new Xml.Node( null, "review" );
    Xml.Node* jsnode = new Xml.Node( null, "journals" );
    Xml.Node* tsnode = new Xml.Node( null, "tags" );

    node->set_prop( "name", _name );
    node->set_prop( "search", _search_str );
    node->set_prop( "all-journals", _all_journals.to_string() );
    node->set_prop( "all-tags", _all_tags.to_string() );

    if( !_all_journals ) {
      foreach( var journal in journals ) {
        Xml.Node* jnode = new Xml.Node( null, "journal" );
        jnode->set_prop( "name", journal );
        jsnode->add_child( jnode );
      }
    }

    if( !_all_tags ) {
      foreach( var tag in tags ) {
        Xml.Node* tnode = new Xml.Node( null, "tag" );
        tnode->set_prop( "name", tag );
        tsnode->add_child( tnode );
      }
    }

    node->add_child( jsnode );
    node->add_child( tsnode );
    node->add_child( _start_date.save( true ) );
    node->add_child( _end_date.save( false ) );

    return( node );

  }

  /* Loads the journals */
  private void load_journals( Xml.Node* node ) {

    for( Xml.Node* it = node->children; it != null; it = it->next ) {
      if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "journal") ) {
        _journals.append( it->get_prop( "name" ) );
      }
    }

  }

  /* Loads the tags */
  private void load_tags( Xml.Node* node ) {

    for( Xml.Node* it = node->children; it != null; it = it->next ) {
      if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "tag") ) {
        _tags.append( it->get_prop( "name" ) );
      }
    }

  }

  /* Loads the absolute date stored in the given XML node */
  private AbsoluteDate load_absolute_date( Xml.Node* node ) {
    var date = new AbsoluteDate.from_xml( node );
    return( date );
  }

  /* Loads the relative date stored in the given XML node */
  private RelativeDate load_relative_date( Xml.Node* node ) {
    var date = new RelativeDate.from_xml( node );
    return( date );
  }

  /* Loads the saved review information from XML mode */
  public void load( Xml.Node* node ) {

    _name       = node->get_prop( "name" );
    _search_str = node->get_prop( "search" );

    var j = node->get_prop( "all-journals" );
    if( j != null ) {
      _all_journals = bool.parse( j );
    }

    var t = node->get_prop( "all-tags" );
    if( t != null ) {
      _all_tags = bool.parse( t );
    }

    for( Xml.Node* it = node->children; it != null; it = it->next ) {
      if( it->type == Xml.ElementType.ELEMENT_NODE ) {
        switch( it->name ) {
          case "journals"            :  load_journals( it );  break;
          case "tags"                :  load_tags( it );      break;
          case "absolute-start-date" :  _start_date = load_absolute_date( it );  break;
          case "relative-start-date" :  _start_date = load_relative_date( it );  break;
          case "absolute-end-date"   :  _end_date   = load_absolute_date( it );  break;
          case "relative-end-date"   :  _end_date   = load_relative_date( it );  break;
        }
      }
    }

  }

}
