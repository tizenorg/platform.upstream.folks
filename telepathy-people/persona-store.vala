/*
 * Copyright (C) 2010 Collabora Ltd.
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
 * Authors:
 *       Travis Reitter <travis.reitter@collabora.co.uk>
 */

using GLib;
using Tp.Individual;
using Tp.Channel;
using Tp.Handle;
using Tp.Account;
using Tp.AccountManager;
using Tp.Lowlevel;

/* FIXME: split out the TpAccount-specific parts into a new subclass, since
 * PersonaStore should also be used by non-Telepathy sources */
public class Tp.PersonaStore : Object {
        [Property(nick = "basis account",
                        blurb = "Telepathy account this store is based upon")]
        public Account account { get; construct; }
        private bool conn_prepared = false;
        private Lowlevel ll;

        private void group_members_changed_cb (Channel channel,
                        string message,
                        /* FIXME: the "unowned" part is just a hack to prevent
                         * the handle from being freed -- we really need to
                         * specify that the Handle is not an object */
                        Array<unowned Handle> added,
                        Array<unowned Handle> removed,
                        Array<unowned Handle> local_pending,
                        Array<unowned Handle> remote_pending,
                        uint actor,
                        uint reason) {
                uint i;

                /* FIXME: cut this */
                stdout.printf ("group members changed: '%s'\n", message);

                for (i = 0; i < added.length; i++) {
                        /* FIXME: the "unowned" part is just a hack to prevent
                         * the handle from being freed -- we really need to
                         * specify that the Handle is not an object */
                        unowned Handle h = added.index (i);

                        /* FIXME: cut this */
                        stdout.printf ("group-members-changed: got handle: %p\n", h);

                        /* FIXME: probably need to improve the telepathy-vala
                         * binding for Tp.Handle before we can do anything
                         * useful */

                        /* FIXME: create the Tp.Individual, etc. */
                }

                /* FIXME: continue for the other arrays */
        }

        private async void add_channel (Connection conn, string name) {
                Channel channel;

                debug ("trying to add channel %s", name);

                /* FIXME: handle the error GLib.Error from this function */
                try {
                        channel = yield this.ll.connection_open_contact_list_channel_async (
                                        conn, name);
                } catch (GLib.Error e) {
                        stderr.printf ("failed to add channel '%s': %s\n",
                                        name, e.message);

                        /* XXX: assuming there's no decent way to recover from
                         * this */

                        return;
                }

                /* FIXME: cut this */
                stdout.printf ("got channel %p (%s, is ready: %u) for store %p\n", channel,
                                channel.get_identifier (), (uint) channel.is_ready (),
                                this);

                channel.group_members_changed.connect (
                                this.group_members_changed_cb);

                channel.notify["channel-ready"].connect ((s, p) => {
                        stdout.printf ("new value for 'channel-ready': %d\n", 
                                (int) channel.channel_ready);

                });
        }

        private void connection_ready_cb (Connection conn, GLib.Error error) {
                if (error != null) {
                        /* FIXME: cut this */
                        stdout.printf ("connection_ready_cb: non-NULL error: %s\n",
                                        error.message);

                } else if (this.conn_prepared == false) {
                        /* FIXME: cut this */
                        stdout.printf ("connection_ready_cb: success\n");

                        /* FIXME: set up a handler for the "NewChannels" signal;
                         * do much the same work in the handler as we do in the
                         * ensure_channel callback (in tp-lowlevel);
                         * remove it once we've received channels for all of
                         * {stored, publish, subscribe}
                         * */

                        /* FIXME: uncomment these
                        this.add_channel (conn, "stored");
                        this.add_channel (conn, "publish");
                        */
                        this.add_channel (conn, "subscribe");

                        this.conn_prepared = true;
                }
        }

        private async void prep_account () {
                bool success;

                /* FIXME: cut this */
                stdout.printf ("about to prep the account\n");

                try {
                        success = yield account.prepare_async (null);
                        if (success == true) {
                                Connection conn = account.get_connection ();

                                /* FIXME: cut this */
                                stdout.printf ("account prep for %s succeeded\n",
                                                this.account.get_display_name ());

                                if (conn == null) {
                                        /* FIXME: cut this */
                                        stdout.printf ("connection offline\n");
                                } else {
                                        /* FIXME: cut this */
                                        stdout.printf ("connection online\n");

                                        conn.call_when_ready (this.connection_ready_cb);
                                }
                        }
                } catch (GLib.Error e) {
                        stderr.printf ("failed to prepare the account '%s': %s",
                                        this.account.get_display_name (),
                                        e.message);
                }
        }

        public PersonaStore (Account account) {
                string status = null;
                string status_message = null;

                /* FIXME: cut this */
                stdout.printf ("creating PersonaStore from account: %p (%s: '%s'), presence: (%d: %s; %s)\n",
                               account,
                               account.get_protocol (),
                               account.get_display_name (),
                               account.get_current_presence (out status,
                                       out status_message),
                               status == null ? status : "(no status)",
                               status_message == null ? status_message : "(no status message)");
                stdout.printf ("second try with status: (%s, %s)\n",
                                status, status_message);


                Object (account: account);

                this.ll = new Lowlevel ();
                this.prep_account ();

                /* FIXME: we need to react to the account going on an offline */
        }
}
