/*
 * Copyright (C) 2011 Collabora Ltd.
 *
 * This library is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors: Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 *
 */

using Tracker.Sparql;
using TrackerTest;
using Folks;
using Gee;

public class EmailsUpdatesTests : Folks.TestCase
{
  private TrackerTest.Backend _tracker_backend;
  private IndividualAggregator _aggregator;
  private GLib.MainLoop _main_loop;
  private string _individual_id;
  private bool _initial_email_found;
  private string _initial_fullname_1;
  private bool _updated_email_found;
  private string _email_1;
  private string _email_2;
  private string _contact_urn_1;

  public EmailsUpdatesTests ()
    {
      base ("EmailsUpdates");

      this._tracker_backend = new TrackerTest.Backend ();
      this._tracker_backend.debug = false;

      this.add_test ("emails updates", this.test_emails_updates);
    }

  public override void set_up ()
    {
    }

  public override void tear_down ()
    {
    }

  public void test_emails_updates ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._initial_fullname_1 = "persona #1";
      this._contact_urn_1 = "<urn:contact001>";
      this._email_1 = "persona-addr-1@example.org";
      this._email_2 = "persona-addr-2@example.org";

      c1.set (TrackerTest.Backend.URN, this._contact_urn_1);
      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._initial_fullname_1);
      c1.set (Trf.OntologyDefs.NCO_EMAIL_PROP, this._email_1);
      this._tracker_backend.add_contact (c1);

      this._tracker_backend.set_up ();

      this._individual_id = "";
      this._initial_email_found = false;
      this._updated_email_found = false;

      this._test_emails_updates_async ();

      Timeout.add_seconds (5, () =>
        {
          this._main_loop.quit ();
          assert_not_reached ();
        });

      this._main_loop.run ();

      assert (this._initial_email_found == true);

      bool initial_email_found_again = false;

      var i = this._aggregator.individuals.lookup (this._individual_id);
      if (i != null)
        {
          foreach (var fd in i.email_addresses)
            {
              var email = fd.value;
              if (email == this._email_1)
                {
                  initial_email_found_again = true;
                }
            }
        }

      assert (initial_email_found_again == false);
      assert (this._updated_email_found == true);

      this._tracker_backend.tear_down ();
    }

  private async void _test_emails_updates_async ()
    {
      var store = BackendStore.dup ();
      yield store.prepare ();
      this._aggregator = new IndividualAggregator ();
      this._aggregator.individuals_changed.connect
          (this._individuals_changed_cb);
      try
        {
          yield this._aggregator.prepare ();
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Error when calling prepare: %s\n", e.message);
        }
    }

  private void _individuals_changed_cb
      (GLib.List<Individual>? added,
       GLib.List<Individual>? removed,
       string? message,
       Persona? actor,
       GroupDetails.ChangeReason reason)
    {
      foreach (unowned Individual i in added)
        {
          if (i.full_name == this._initial_fullname_1)
            {
              this._individual_id = i.id;
              i.notify["email-addresses"].connect (this._notify_email_cb);

              foreach (var fd in i.email_addresses)
                {
                  var email = fd.value;
                  if (email == this._email_1)
                    {
                      this._initial_email_found = true;

                      var urn_email_1 = "<" + this._email_1 + ">";
                      this._tracker_backend.remove_triplet (this._contact_urn_1,
                          Trf.OntologyDefs.NCO_HAS_AFFILIATION, urn_email_1);

                      var urn_email_2 = "<email:" + this._email_2 + ">";
                      this._tracker_backend.insert_triplet (urn_email_2,
                          "a", Trf.OntologyDefs.NCO_EMAIL,
                          Trf.OntologyDefs.NCO_EMAIL_PROP,
                          this._email_2);

                      var affl_2 = "<" + this._email_2 + ">";
                      this._tracker_backend.insert_triplet
                          (affl_2,
                          "a", Trf.OntologyDefs.NCO_AFFILIATION);

                      this._tracker_backend.insert_triplet
                          (affl_2,
                          Trf.OntologyDefs.NCO_HAS_EMAIL, urn_email_2);

                      this._tracker_backend.insert_triplet
                          (this._contact_urn_1,
                          Trf.OntologyDefs.NCO_HAS_AFFILIATION, affl_2);
                    }
                }
            }
        }

      assert (removed == null);
    }

  private void _notify_email_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual individual = (Folks.Individual) individual_obj;

      if (this._individual_id != individual.id)
        return;

      foreach (var fd in individual.email_addresses)
        {
          var email = fd.value;
          if (email == this._email_2)
            {
              this._updated_email_found = true;
              this._main_loop.quit ();
            }
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new EmailsUpdatesTests ().get_suite ());

  Test.run ();

  return 0;
}
