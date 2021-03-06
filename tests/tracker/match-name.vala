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

public class MatchNameTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator = null;
  private string _persona_fullname_1 = "Bernie Innocenti";
  private string _persona_fullname_2 = "Bernardo H. Innocenti";
  private bool _added_personas;
  private string _individual_id_1 = "";
  private string _individual_id_2 = "";
  private Folks.MatchResult _match;
  private Trf.PersonaStore _pstore;

  public MatchNameTests ()
    {
      base ("MatchNameTests");

      this.add_test ("test potential match by name #1 ",
          this.test_match_name_1);
      this.add_test ("test potential match by name #2 ",
          this.test_match_name_2);
      this.add_test ("test potential match by name #3 ",
          this.test_match_name_3);
      this.add_test ("test potential match by name #4 ",
          this.test_match_name_4);
      this.add_test ("test potential match by name #5 ",
          this.test_match_name_5);
      this.add_test ("test potential match by name #6 ",
          this.test_match_name_6);
    }

  private void _test_match_name (string full_name1, string full_name2)
    {
      this._main_loop = new GLib.MainLoop (null, false);

      this._match = Folks.MatchResult.MIN;
      this._added_personas = false;
      this._persona_fullname_1 = full_name1;
      this._persona_fullname_2 = full_name2;
      this._individual_id_1 = "";
      this._individual_id_2 = "";

      this._test_match_name_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);
    }

  public void test_match_name_1 ()
    {
      this._test_match_name ("Bernie Innocenti", "Bernardo H. Innocenti");
      assert (this._match >= Folks.MatchResult.MEDIUM);
    }

  public void test_match_name_2 ()
    {
      this._test_match_name ("AAAA BBBBB", "CCCCC DDDDD");
      assert (this._match <= Folks.MatchResult.LOW);
    }

  public void test_match_name_3 ()
    {
      this._test_match_name ("Travis Reitter", "Travis R.");
      assert (this._match >= Folks.MatchResult.MEDIUM);
    }

  public void test_match_name_4 ()
    {
      /* Chosen to test the accent- and case-invariance of the matching
       * algorithm. The string's repeated so the string lengths get us up to
       * a MEDIUM result. */
      this._test_match_name ("PâtéPâtéPâté", "patepatepate");
      assert (this._match >= Folks.MatchResult.MEDIUM);
    }

  public void test_match_name_5 ()
    {
      /* bgo#678474 */
      this._test_match_name ("Frédéric Peters", "Frederic Peters");
      assert (this._match >= Folks.MatchResult.HIGH);
    }

  public void test_match_name_6 ()
    {
      /* Another one from bgo#678474, testing random punctuation in names */
      this._test_match_name ("Alice Badger", "alice.badger");
      assert (this._match >= Folks.MatchResult.HIGH);
    }

  private async void _test_match_name_async ()
    {
      var store = BackendStore.dup ();
      yield store.prepare ();

      if (this._aggregator == null)
        {
          this._aggregator = IndividualAggregator.dup ();
          this._aggregator.individuals_changed_detailed.connect
            (this._individuals_changed_cb);
        }

      try
        {
          yield this._aggregator.prepare ();
          this._pstore = null;
          foreach (var backend in store.enabled_backends.values)
            {
              this._pstore =
                (Trf.PersonaStore) backend.persona_stores.get ("tracker");
              if (this._pstore != null)
                break;
            }
          assert (this._pstore != null);
          this._pstore.notify["is-prepared"].connect (this._notify_pstore_cb);
          this._try_to_add.begin ();
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Error when calling prepare: %s\n", e.message);
        }
    }

  private void _individuals_changed_cb (
       MultiMap<Individual?, Individual?> changes)
    {
      var added = changes.get_values ();
      var removed = changes.get_keys ();

      foreach (var i in added)
        {
          assert (i != null);

          if (i.full_name == this._persona_fullname_1)
            {
              this._individual_id_1 = i.id;
            }
          else if (i.full_name == this._persona_fullname_2)
            {
              this._individual_id_2 = i.id;
            }
        }

      if (this._individual_id_1 != "" &&
          this._individual_id_2 != "")
        {
          this._try_potential_match ();
        }

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }
    }

  private void _try_potential_match ()
    {
      var ind1 = this._aggregator.individuals.get (this._individual_id_1);
      var ind2 = this._aggregator.individuals.get (this._individual_id_2);

      Folks.PotentialMatch matchObj = new Folks.PotentialMatch ();
      this._match = matchObj.potential_match (ind1, ind2);

      this._main_loop.quit ();
    }

  private void _notify_pstore_cb (Object _pstore, ParamSpec ps)
    {
      this._try_to_add.begin ();
    }

  private async void _try_to_add ()
    {
      if (this._pstore.is_prepared && this._added_personas == false)
        {
          this._added_personas = true;
          yield this._add_personas ();
        }
    }

  private async void _add_personas ()
    {
      HashTable<string, Value?> details1 = new HashTable<string, Value?>
          (str_hash, str_equal);
      HashTable<string, Value?> details2 = new HashTable<string, Value?>
          (str_hash, str_equal);
      Value? val;

      val = Value (typeof (string));
      val.set_string (this._persona_fullname_1);
      details1.insert (Folks.PersonaStore.detail_key (PersonaDetail.FULL_NAME),
          (owned) val);

      val = Value (typeof (string));
      val.set_string (this._persona_fullname_2);
      details2.insert (Folks.PersonaStore.detail_key (PersonaDetail.FULL_NAME),
          (owned) val);

     try
        {
          yield this._aggregator.add_persona_from_details (null,
              this._pstore, details1);

          yield this._aggregator.add_persona_from_details (null,
              this._pstore, details2);
        }
      catch (Folks.IndividualAggregatorError e)
        {
          GLib.warning ("[AddPersonaError] add_persona_from_details: %s\n",
              e.message);
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new MatchNameTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
