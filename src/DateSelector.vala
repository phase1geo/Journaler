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

public class DateSelector : Entry {

  public DateTime default_date { get; set; default = new DateTime.now_local(); }
  public DateTime date         { get; set; default = new DateTime.now_local(); }

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
    editable             = false;
    primary_icon_gicon   = new ThemedIcon.with_default_fallbacks ("office-calendar-symbolic");
    secondary_icon_gicon = new ThemedIcon.with_default_fallbacks ("pan-down-symbolic");

    primary_icon_tooltip_text   = _( "Reset date to default" );
    secondary_icon_tooltip_text = _( "Select date with date picker" );

    add_css_class( "date-picker" );

    icon_release.connect((pos) => {
      if( pos == EntryIconPosition.PRIMARY ) {
        date = default_date;
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

  /* Sets the current date to the default date */
  public void set_to_default() {
    date = default_date;
  }

}
