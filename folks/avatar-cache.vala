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
 * Authors:
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 */

using GLib;

/**
 * A singleton persistent cache object for avatars used across backends in
 * folks. Avatars may be added to the cache, and referred to by a persistent
 * URI from that point onwards.
 *
 * @since UNRELEASED
 */
public class Folks.AvatarCache : Object
{
  private static weak AvatarCache _instance = null; /* needs to be locked */
  private File _cache_directory;

  /**
   * Private constructor for an instance of the avatar cache. The singleton
   * instance should be retrieved by calling {@link AvatarCache.dup()} instead.
   *
   * @since UNRELEASED
   */
  private AvatarCache ()
    {
      this._cache_directory =
          File.new_for_path (Environment.get_user_cache_dir ())
              .get_child ("folks")
              .get_child ("avatars");
    }

  /**
   * Create or return the singleton {@link AvatarCache} class instance.
   * If the instance doesn't exist already, it will be created.
   *
   * This function is thread-safe.
   *
   * @return Singleton {@link AvatarCache} instance
   * @since UNRELEASED
   */
  public static AvatarCache dup ()
    {
      lock (AvatarCache._instance)
        {
          var retval = AvatarCache._instance;

          if (retval == null)
            {
              /* use an intermediate variable to force a strong reference */
              retval = new AvatarCache ();
              AvatarCache._instance = retval;
            }

          return retval;
        }
    }

  ~AvatarCache ()
    {
      /* Manually clear the singleton _instance */
      lock (AvatarCache._instance)
        {
          AvatarCache._instance = null;
        }
    }

  /**
   * Fetch an avatar from the cache by its globally unique ID.
   *
   * @param id the globally unique ID for the avatar
   * @return Avatar from the cache, or `null` if it doesn't exist in the cache
   * @throws GLib.Error if checking for existence of the cache file failed
   * @since UNRELEASED
   */
  public async LoadableIcon? load_avatar (string id) throws GLib.Error
    {
      var avatar_file = this._get_avatar_file (id);

      // Return null if the avatar doesn't exist
      if (avatar_file.query_exists () == false)
        {
          return null;
        }

      return new FileIcon (avatar_file);
    }

  /**
   * Store an avatar in the cache, assigning the given globally unique ID to it,
   * which can later be used to load and remove the avatar from the cache. For
   * example, this ID could be the UID of a persona. The URI of the cached
   * avatar file will be returned.
   *
   * @param id the globally unique ID for the avatar
   * @param avatar the avatar data to cache
   * @return a URI for the file storing the cached avatar
   * @throws GLib.Error if the avatar data couldn't be loaded, or if creating
   * the avatar directory or cache file failed
   * @since UNRELEASED
   */
  public async string store_avatar (string id, LoadableIcon avatar)
      throws GLib.Error
    {
      var dest_avatar_file = this._get_avatar_file (id);

      // Copy the icon data into a file
      while (true)
        {
          InputStream src_avatar_stream =
              yield avatar.load_async (-1, null, null);

          try
            {
              OutputStream dest_avatar_stream =
                  yield dest_avatar_file.replace_async (null, false,
                      FileCreateFlags.PRIVATE);

              yield dest_avatar_stream.splice_async (src_avatar_stream,
                  OutputStreamSpliceFlags.CLOSE_SOURCE |
                      OutputStreamSpliceFlags.CLOSE_TARGET);

              break;
            }
          catch (GLib.Error e)
            {
              /* If the parent directory wasn't found, create it and loop
               * round to try again. */
              if (e is IOError.NOT_FOUND)
                {
                  this._create_cache_directory ();
                  continue;
                }

              throw e;
            }
        }

      return this.build_uri_for_avatar (id);
    }

  /**
   * Remove an avatar from the cache, if it exists in the cache. If the avatar
   * exists in the cache but there is a problem in removing it, a
   * {@link GLib.Error} will be thrown.
   *
   * @param id the globally unique ID for the avatar
   * @throws GLib.Error if deleting the cache file failed
   * @since UNRELEASED
   */
  public async void remove_avatar (string id) throws GLib.Error
    {
      var avatar_file = this._get_avatar_file (id);
      try
        {
          avatar_file.delete (null);
        }
      catch (GLib.Error e)
        {
          // Ignore file not found errors
          if (!(e is IOError.NOT_FOUND))
            {
              throw e;
            }
        }
    }

  /**
   * Build the URI of an avatar file in the cache from a globally unique ID.
   * This will always succeed, even if the avatar doesn't exist in the cache.
   *
   * @param id the globally unique ID for the avatar
   * @return URI of the avatar file with the given globally unique ID
   * @since UNRELEASED
   */
  public string build_uri_for_avatar (string id)
    {
      return this._get_avatar_file (id).get_uri ();
    }

  private File _get_avatar_file (string id)
    {
      var escaped_uri = Uri.escape_string (id, "", false);
      var file = this._cache_directory.get_child (escaped_uri);

      assert (file.has_parent (this._cache_directory) == true);

      return file;
    }

  private void _create_cache_directory () throws GLib.Error
    {
      try
        {
          this._cache_directory.make_directory_with_parents ();
        }
      catch (GLib.Error e)
        {
          // Ignore errors caused by the directory existing already
          if (!(e is IOError.EXISTS))
            {
              throw e;
            }
        }
    }
}