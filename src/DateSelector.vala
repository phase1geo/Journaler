using Gtk;

public class DateSelector : Entry {

  public DateTime date { get; set; default = new DateTime.now_local(); }

  /* Default constructor */
  public DateSelector() {

    var calendar = new Calendar();

    var popover = new Gtk.Popover () {
      halign    = Gtk.Align.END,
      autohide  = true,
      has_arrow = false,
      child     = calendar
    };
    popover.set_parent( this );

    /* Entry properties */
    editable = false;
    primary_icon_gicon   = new ThemedIcon.with_default_fallbacks ("office-calendar-symbolic");
    secondary_icon_gicon = new ThemedIcon.with_default_fallbacks ("pan-down-symbolic");

    add_css_class( "date-picker" );

    icon_release.connect((pos) => {
      if( pos == EntryIconPosition.PRIMARY ) {
        date = new DateTime.now_local();
      } else {
        popover.popup();
      }
    });

    calendar.day_selected.connect(() => {
      date = new GLib.DateTime.local( calendar.year, (calendar.month + 1), calendar.day, 0, 0, 0 );
      popover.popdown();
    });

    calendar.next_month.connect(() => {
      date = new GLib.DateTime.local( calendar.year, (calendar.month + 1), calendar.day, 0, 0, 0 );
    });

    calendar.prev_month.connect(() => {
      date = new GLib.DateTime.local( calendar.year, (calendar.month + 1), calendar.day, 0, 0, 0 );
    });

    calendar.next_year.connect(() => {
      date = new GLib.DateTime.local( calendar.year, (calendar.month + 1), calendar.day, 0, 0, 0 );
    });

    calendar.prev_year.connect(() => {
      date = new GLib.DateTime.local( calendar.year, (calendar.month + 1), calendar.day, 0, 0, 0 );
    });

    notify["date"].connect(() => {
      text = date.format( "%Y-%m-%d" );
      calendar.select_day( date );
    });

  }

}
