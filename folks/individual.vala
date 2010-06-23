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

using Gee;
using GLib;
using Folks;

/**
 * A physical person, aggregated from the various {@link Persona}s the person
 * might have, such as their different IM addresses or vCard entries.
 */
public class Folks.Individual : Object, Alias, Avatar, Capabilities, Groups,
       Presence, Favourite
{
  private HashTable<string, bool> _groups;
  private GLib.List<Persona> _personas;
  private HashTable<PersonaStore, HashSet<Persona>> stores;
  private bool _is_favourite;

  /* XXX: should setting this push it down into the Persona (to foward along to
   * the actual store if possible?) */
  public string alias { get; set; }
  public File avatar { get; set; }
  public CapabilitiesFlags capabilities { get; private set; }
  public string id { get; private set; }
  public Folks.PresenceType presence_type { get; private set; }
  public string presence_message { get; private set; }
  public bool is_favourite
    {
      get { return this._is_favourite; }

      /* Propagate the new favourite status to every Persona, but only if it's
       * changed. */
      set
        {
          if (this._is_favourite == value)
            return;

          this._is_favourite = true;
          this._personas.foreach ((p) =>
            {
              if (p is Favourite)
                ((Favourite) p).is_favourite = value;
            });
        }
    }

  /* the last of this individuals personas has been removed, so it is invalid */
  public signal void removed ();

  public HashTable<string, bool> groups
    {
      get { return this._groups; }

      /* Propagate the list of new groups to every Persona in the individual
       * which implements the Groups interface */
      set
        {
          this._personas.foreach ((p) =>
            {
              if (p is Groups)
                ((Groups) p).groups = value;
            });
        }
    }

  public GLib.List<Persona> personas
    {
      get { return this._personas; }

      set
        {
          /* Disconnect from all our previous personas */
          this._personas.foreach ((p) =>
            {
              var persona = (Persona) p;
              var groups = (p is Groups) ? (Groups) p : null;

              persona.notify["avatar"].disconnect (this.notify_avatar_cb);
              persona.notify["presence-message"].disconnect (
                  this.notify_presence_cb);
              persona.notify["presence-type"].disconnect (
                  this.notify_presence_cb);
              persona.notify["is-favourite"].disconnect (
                  this.notify_is_favourite_cb);
              groups.group_changed.disconnect (this.persona_group_changed_cb);
            });

          this._personas = value.copy ();

          /* If all the personas have been removed, remove the individual */
          if (this._personas.length () < 1)
            {
              this.removed ();
              return;
            }

          /* TODO: base this upon our ID in permanent storage, once we have that
           */
          if (this.id == null && this._personas.data != null)
            this.id = this._personas.data.iid;

          /* Connect to all the new personas */
          this._personas.foreach ((p) =>
            {
              var persona = (Persona) p;
              var groups = (p is Groups) ? (Groups) p : null;

              persona.notify["avatar"].connect (this.notify_avatar_cb);
              persona.notify["presence-message"].connect (
                  this.notify_presence_cb);
              persona.notify["presence-type"].connect (this.notify_presence_cb);
              persona.notify["is-favourite"].connect (
                  this.notify_is_favourite_cb);
              groups.group_changed.connect (this.persona_group_changed_cb);
            });

          /* Update our aggregated fields and notify the changes */
          this.update_fields ();
        }
    }

  private void notify_avatar_cb (Object obj, ParamSpec ps)
    {
      this.update_avatar ();
    }

  private void persona_group_changed_cb (string group, bool is_member)
    {
      this.change_group (group, is_member);
      this.update_groups ();
    }

  public void change_group (string group, bool is_member)
    {
      this._personas.foreach ((p) =>
        {
          if (p is Groups)
            ((Groups) p).change_group (group, is_member);
        });

      /* don't notify, since it hasn't happened in the persona backing stores
       * yet; react to that directly */
    }

  private void notify_presence_cb (Object obj, ParamSpec ps)
    {
      this.update_presence ();
    }

  private void notify_is_favourite_cb (Object obj, ParamSpec ps)
    {
      this.update_is_favourite ();
    }

  public Individual (GLib.List<Persona>? personas)
    {
      Object (personas: personas);

      this.stores = new HashTable<PersonaStore, HashSet<Persona>> (direct_hash,
          direct_equal);
      this.stores_update ();
    }

  private void stores_update ()
    {
      this._personas.foreach ((p) =>
        {
          var persona = (Persona) p;
          var store_is_new = false;
          var persona_set = this.stores.lookup (persona.store);
          if (persona_set == null)
            {
              persona_set = new HashSet<Persona> (direct_hash, direct_equal);
              store_is_new = true;
            }

          persona_set.add (persona);

          if (store_is_new)
            {
              this.stores.insert (persona.store, persona_set);

              persona.store.removed.connect (this.store_removed_cb);
              persona.store.personas_removed.connect (
                this.store_personas_removed_cb);
            }
        });
    }

  private void store_removed_cb (PersonaStore store)
    {
      var persona_set = this.stores.lookup (store);
      if (persona_set != null)
        {
          foreach (var persona in persona_set)
            {
              this._personas.remove (persona);
            }
        }
      if (store != null)
        this.stores.remove (store);

      if (this._personas.length () < 1 || this.stores.size () < 1)
        {
          this.removed ();
          return;
        }

      this.update_fields ();
    }

  private void store_personas_removed_cb (PersonaStore store,
      GLib.List<Persona> personas)
    {
      personas.foreach ((data) =>
        {
          this._personas.remove ((Persona) data);
        });

      if (this._personas.length () < 1)
        {
          this.removed ();
          return;
        }

      this.update_fields ();
    }

  private void update_fields ()
    {
      /* Gather the first occurrence of each field. We assume that there is
       * at least one persona in the list, since the Individual should've been
       * destroyed before now otherwise. */
      string alias = null;
      var caps = CapabilitiesFlags.NONE;
      this._personas.foreach ((persona) =>
        {
          var p = (Persona) persona;

          /* FIXME: also check to see if alias is just whitespace */
          if (alias == null)
            alias = p.alias;

          caps |= p.capabilities;
        });

      if (alias == null)
        {
          /* We have to pick a UID, since none of the personas have an alias
           * available. Pick the UID from the first persona in the list. */
          alias = this._personas.data.uid;
          warning ("No aliases available for individual; using UID instead: %s",
                   alias);
        }

      /* only notify if the value has changed */
      if (this.alias != alias)
        this.alias = alias;

      if (this.capabilities != caps)
        this.capabilities = caps;

      this.update_groups ();
      this.update_presence ();
      this.update_is_favourite ();
      this.update_avatar ();
    }

  private void update_groups ()
    {
      var new_groups = new HashTable<string, bool> (str_hash, str_equal);

      /* this._groups is null during initial construction */
      if (this._groups == null)
        this._groups = new HashTable<string, bool> (str_hash, str_equal);

      /* FIXME: this should partition the personas by store (maybe we should
       * keep that mapping in general in this class), and execute
       * "groups-changed" on the store (with the set of personas), to allow the
       * back-end to optimize it (like Telepathy will for MembersChanged for the
       * groups channel list) */
      this._personas.foreach ((p) =>
        {
          if (p is Groups)
            {
              var persona = (Groups) p;

              persona.groups.foreach ((k, v) =>
                {
                  new_groups.insert ((string) k, true);
                });
            }
        });

      new_groups.foreach ((k, v) =>
        {
          var group = (string) k;
          if (this._groups.lookup (group) != true)
            {
              this._groups.insert (group, true);
              this._groups.foreach ((k, v) =>
                {
                  var g = (string) k;
                  debug ("   %s", g);
                });

              this.group_changed (group, true);
            }
        });

      /* buffer the removals, so we don't remove while iterating */
      var removes = new GLib.List<string> ();
      this._groups.foreach ((k, v) =>
        {
          var group = (string) k;
          if (new_groups.lookup (group) != true)
            removes.prepend (group);
        });

      removes.foreach ((l) =>
        {
          var group = (string) l;
          this._groups.remove (group);
          this.group_changed (group, false);
        });
    }

  private void update_presence ()
    {
      var presence_message = "";
      var presence_type = Folks.PresenceType.UNSET;

      /* Choose the most available presence from our personas */
      this._personas.foreach ((p) =>
        {
          var persona = (Persona) p;

          if (Presence.typecmp (persona.presence_type, presence_type) > 0)
            {
              presence_type = persona.presence_type;
              presence_message = persona.presence_message;
            }
        });

      if (presence_message == null)
        presence_message = "";

      /* only notify if the value has changed */
      if (this.presence_message != presence_message)
        this.presence_message = presence_message;

      if (this.presence_type != presence_type)
        this.presence_type = presence_type;
    }

  private void update_is_favourite ()
    {
      bool favourite = false;

      this._personas.foreach ((persona) =>
        {
          var p = (Persona) persona;

          if (favourite == false)
            favourite = p.is_favourite;
        });

      /* Only notify if the value has changed */
      if (this._is_favourite != favourite)
        this._is_favourite = favourite;
    }

  private void update_avatar ()
    {
      File avatar = null;

      this._personas.foreach ((p) =>
        {
          var persona = (Persona) p;

          if (avatar == null)
            {
              avatar = persona.avatar;
              return;
            }
        });

      /* only notify if the value has changed */
      if (this.avatar != avatar)
        this.avatar = avatar;
    }

  public CapabilitiesFlags get_capabilities ()
    {
      return this.capabilities;
    }

  /*
   * GLib/C convenience functions (for built-in casting, etc.)
   */
  public unowned string get_alias ()
    {
      return this.alias;
    }

  public HashTable<string, bool> get_groups ()
    {
      Groups g = this;
      return g.groups;
    }

  public unowned string get_presence_message ()
    {
      return this.presence_message;
    }

  public Folks.PresenceType get_presence_type ()
    {
      return this.presence_type;
    }

  public bool is_online ()
    {
      Presence p = this;
      return p.is_online ();
    }
}
