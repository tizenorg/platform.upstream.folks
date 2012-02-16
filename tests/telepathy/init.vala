/*
 * Copyright (C) 2012 Philip Withnall
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
 * Authors: Philip Withnall <philip@tecnocode.co.uk>
 */

using Gee;
using Folks;

public class InitTests : Folks.TestCase
{
  private TpTest.Backend _tp_backend;
  private int _test_timeout = 5;

  public InitTests ()
    {
      base ("Init");

      this._tp_backend = new TpTest.Backend ();

      /* Set up the tests */
      this.add_test ("quiescence", this.test_quiescence);
    }

  public override void set_up ()
    {
      this._tp_backend.set_up ();
    }

  public override void tear_down ()
    {
      this._tp_backend.tear_down ();
    }

  /* Prepare an aggregator and wait for quiescence, then quit. Error if reaching
   * quiescence takes too long. */
  public void test_quiescence ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      void* account_handle = this._tp_backend.add_account ("protocol",
          "me@example.com", "cm", "account");

      /* Main test code. */
      var aggregator = new IndividualAggregator ();

      Idle.add (() =>
        {
          TestUtils.aggregator_prepare_and_wait_for_quiescence.begin (
              aggregator, (obj, res) =>
            {
              try
                {
                  TestUtils.aggregator_prepare_and_wait_for_quiescence.end (
                      res);
                }
              catch (GLib.Error e1)
                {
                  GLib.critical ("Error preparing aggregator: %s", e1.message);
                }

              main_loop.quit ();
            });

          return false;
        });

      /* Add a timeout for failure. */
      Timeout.add_seconds (this._test_timeout, () =>
        {
          main_loop.quit ();
          return false;
        });

      main_loop.run ();

      /* Check results. */
      assert (aggregator.is_quiescent == true);
      assert (aggregator.individuals.size > 0);

      /* Clean up for the next test */
      this._tp_backend.remove_account (account_handle);
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new InitTests ().get_suite ());

  Test.run ();

  return 0;
}