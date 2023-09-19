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

public class GoalCount : Goal {

  /* Default constructor */
  public GoalCount( string label, int goal ) {
    base( "count-%d".printf( goal ), label, goal );
  }

  /* Constructor */
  public GoalCount.from_xml( Xml.Node* node ) {
    base.from_xml( node );
  }

  /* Returns the name of the XML node */
  public override string xml_node_name() {
    return( "goal-count" );
  }

  /* Returns true if the count should be incremented */
  protected override CountAction get_count_action( Date todays_date, Date last_achieved ) {
    return( (last_achieved.days_between( todays_date ) == 0) ? CountAction.NONE : CountAction.INCREMENT );
  }

}
