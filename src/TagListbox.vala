using Gtk;

public class TagListbox : Box {

  private TagList         _added;
  private TagList         _removed;

  private ListBox         _lb;
  private EntryCompletion _add_completion;
  private Button          _save;

  public signal void closed( bool saved );

  public TagList added {
    get {
      return( _added );
    }
  }

  public TagList removed {
    get {
      return( _removed );
    }
  }

  /* Constructor */
  public TagListbox() {

    Object(
      orientation: Orientation.VERTICAL,
      spacing:       5,
      margin_start:  5,
      margin_end:    5,
      margin_top:    5,
      margin_bottom: 5
    );

    _added   = new TagList();
    _removed = new TagList();

    var lbl = new Label( Utils.make_title( _( "Edit Tags" ) ) ) {
      use_markup = true,
      halign = Align.FILL
    };

    _lb = new ListBox() {
      activate_on_single_click = false,
      selection_mode = SelectionMode.MULTIPLE,
      can_focus = true
    };

    var sw = new ScrolledWindow() {
      hscrollbar_policy  = PolicyType.NEVER,
      vscrollbar_policy  = PolicyType.AUTOMATIC,
      min_content_height = 200,
      overlay_scrolling  = true,
      has_frame          = true,
      child              = _lb
    };

    var add = new Button.from_icon_name( "list-add-symbolic" ) {
      halign       = Align.START,
      has_frame    = false,
      tooltip_text = _( "Add tag" )
    };

    var del = new Button.from_icon_name( "list-remove-symbolic" ) {
      halign       = Align.START,
      has_frame    = false,
      sensitive    = false,
      tooltip_text = _( "Remove selected tags" )
    };

    var cancel = new Button.with_label( _( "Cancel" ) ) {
      halign = Align.END,
      hexpand = true
    };

    cancel.clicked.connect(() => {
      closed( false );
    });

    _save = new Button.with_label( _( "Apply" ) ) {
      halign = Align.END,
      sensitive = false
    };

    _save.clicked.connect(() => {
      closed( true );
    });
    _save.add_css_class( "suggested-action" );

    var bbox = new Box( Orientation.HORIZONTAL, 5 );

    bbox.append( add );
    bbox.append( del );
    bbox.append( cancel );
    bbox.append( _save );

    _lb.selected_rows_changed.connect(() => {
      del.sensitive = (_lb.get_selected_rows().length() > 0);
    });

    _add_completion = new EntryCompletion() {
      inline_completion = true,
      inline_selection  = true,
      text_column       = 0
    };

    var add_key = new EventControllerKey();
    var add_entry = new Entry() {
      placeholder_text    = _( "Enter new tag" ),
      secondary_icon_name = "window-close-symbolic",
      completion          = _add_completion
    };
    add_entry.add_controller( add_key );

    var stack = new Stack();

    stack.add_named( bbox,      "button-bar" );
    stack.add_named( add_entry, "add-entry" );

    add_key.key_pressed.connect((keyval, keycode, state) => {
      if( keyval == Gdk.Key.Escape ) {
        add_entry.text = "";
        stack.visible_child_name = "button-bar";
      }
      return( false );
    });

    add.clicked.connect(() => {
      stack.visible_child_name = "add-entry";
      add_entry.grab_focus();
    });

    del.clicked.connect(() => {
      var selected = _lb.get_selected_rows();
      selected.foreach((row) => {
        var rbox = (Box)row.get_child();
        var rlbl = (Label)rbox.get_first_child();
        var tag  = rlbl.label;
        if( !_added.remove_tag( tag ) ) {
          _removed.add_tag( tag );
        }
        _lb.remove( row );
      });
      update_ui_state();
    });

    add_entry.activate.connect(() => {
      var tag = add_entry.text.strip();
      if( tag != "" ) {
        add_tag( add_entry.text, true );
      }
      add_entry.text = "";
      stack.visible_child_name = "button-bar";
      update_ui_state();
    });

    add_entry.icon_release.connect((pos) => {
      stack.visible_child_name = "button-bar";
    });

    append( lbl );
    append( sw );
    append( stack );

  }

  /* Updates the UI state */
  private void update_ui_state() {

    var changed = (_added.length() > 0) || (_removed.length() > 0);

    _save.sensitive = changed;

  }

  /* Clears the list of tags */
  public void clear() {

    var row = _lb.get_row_at_index( 0 );
    while( row != null ) {
      _lb.remove( row );
      row = _lb.get_row_at_index( 0 );
    }

    _added.clear();
    _removed.clear();

  }

  /* Adds a single tag to the listbox */
  private void add_tag( string tag, bool add ) {

    /* Attempt to add the tag to the added tags list */
    if( add && !_added.add_tag( tag ) ) {
      return;
    }

    var label = new Label( tag ) {
      halign = Align.START,
      hexpand = true
    };

    var added = new Label( _( "(New)" ) ) {
      halign = Align.END,
      visible = add
    };

    var box = new Box( Orientation.HORIZONTAL, 10 ) {
      halign        = Align.FILL,
      hexpand       = true,
      margin_start  = 5,
      margin_end    = 5,
      margin_top    = 5,
      margin_bottom = 5
    };
    box.append( label );
    box.append( added );

    _lb.append( box );

  }

  /* Adds the list of tags that exist that can be added */
  public void add_all_tags( TagList tags ) {

    var store = new Gtk.ListStore( 1, typeof(string) );

    tags.foreach((tag) => {
      TreeIter it;
      store.append( out it );
      store.set( it, 0, tag );
    });

    _add_completion.set_model( store );

  }

  /* Adds the given list of tags to the listbox */
  public void add_selected_tags( TagList tags ) {

    clear();

    tags.foreach((tag) => {
      add_tag( tag, false );
    });

  }

}
