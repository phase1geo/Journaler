using Gtk;

public class TagBox : Box {

  private Journal? _journal = null;
  private DBEntry? _entry = null;

  private Box      _box;
  private TagEntry _new_tag_entry;

  private List<Widget>  _tag_widgets;
  private Array<string> _all_tags;

  public Journal? journal {
    get {
      return( _journal );
    }
    set {
      _journal = value;
    }
  }

  public DBEntry? entry {
    get {
      return( _entry );
    }
    set {
      _entry = value;
      update_tags();
    }
  }

  /* Default constructor */
  public TagBox() {

    Object( orientation: Orientation.VERTICAL, spacing: 0 );

    _tag_widgets = new List<Widget>();
    _all_tags    = new Array<string>();

    _new_tag_entry = new TagEntry( _("Click to add tag…") ) {
      add_css = false
    };
    _new_tag_entry.activated.connect((tag) => {
      _entry.add_tag( tag );
      update_tags();
    });

    _box = new Box( Orientation.HORIZONTAL, 5 ) {
      valign = Align.CENTER
    };
    _box.append( new Gtk.Image.from_icon_name( "tag-symbolic" ) );
    _box.append( _new_tag_entry );

    var scroller = new ScrolledWindow() {
      hexpand = true,
      valign  = Align.CENTER
    };
    scroller.child = _box;

    append( scroller );

  }

  /* This should be called whenever the tags change in _entry */
  public void update_tags() {

    /* Refresh the completion data */
    refresh_completion();

    /* Redraw the tags in the UI */
    redraw_tags();

    /* Update the database with the entry changes */
    _journal.db.save_tags_only( _entry );

  }

  /* Updates the completion UI */
  private void refresh_completion () {

    /* Clear the current tags */
    _all_tags.remove_range( 0, _all_tags.length );

    /* Get the tags from the database */
    _journal.db.get_all_tags( _all_tags );

    /* Remove any tags that are currently set for this entry */
    for( int i=(int)(_all_tags.length - 1); i>=0; i-- ) {
      if( (_entry != null) && _entry.contains_tag( _all_tags.index( i ) ) ) {
        _all_tags.remove_index( i );
      }
    }

  }

  /* Redraws the tags */
  private void redraw_tags() {

    /* Delete the tags from the box */
    _box.remove( _new_tag_entry );
    _tag_widgets.foreach((tag_widget) => {
      _box.remove( tag_widget );
      _tag_widgets.remove( tag_widget );
      tag_widget.destroy();
    });

    if( _entry == null ) {
      return;
    }

    foreach( var tag in _entry.tags ) {

      var tag_button = new TagEntry( tag );
      tag_button.populate_completion( _all_tags );

      tag_button.activated.connect((btag) => {
        _entry.replace_tag( tag, btag );
        _journal.db.save_tags_only( _entry );
        update_tags();
      });

      tag_button.removed.connect((btag) => {
        _entry.remove_tag( btag );
        _box.remove( tag_button );
        _tag_widgets.remove( tag_button );
        tag_button.destroy();
      });

      _box.append( tag_button );
      _tag_widgets.append( tag_button );

    }

    _new_tag_entry.populate_completion( _all_tags );
    _new_tag_entry.hide_entry();
    _new_tag_entry.text = "";

    _box.append( _new_tag_entry );

  }

  public void add_class( string name ) {
    add_css_class( name );
  }

  public void remove_class( string name ) {
    remove_css_class( name );
  }

}
