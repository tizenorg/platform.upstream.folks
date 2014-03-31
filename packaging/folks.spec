%define soversion      25
%define module_version 39
%define baseline 0.9

%bcond_with folks_socialweb
%bcond_with folks_telepathy
%bcond_with folks_zeitgeist
%bcond_with folks_ofono

Name:           folks
Version:        0.9.6
Release:        0
Summary:        Library to create metacontacts from multiple sources
License:        LGPL-2.1+
Group:          System/Libraries
Url:            http://telepathy.freedesktop.org/wiki/Folks
Source:         http://download.gnome.org/sources/folks/%{baseline}/%{name}-%{version}.tar.xz
BuildRequires:  intltool >= 0.50.0
BuildRequires:  readline-devel
BuildRequires:  vala >= 0.17.6
BuildRequires:  pkgconfig(dbus-glib-1)
BuildRequires:  pkgconfig(gee-0.8) >= 0.8.4
BuildRequires:  pkgconfig(gobject-2.0) >= 2.32.0
BuildRequires:  pkgconfig(gobject-introspection-1.0) >= 1.30
BuildRequires:  pkgconfig(libebook-1.2) >= 3.7.90
BuildRequires:  pkgconfig(libedataserver-1.2) >= 3.5.3.1
%if %{with folks_socialweb}
BuildRequires:  pkgconfig(libsocialweb-client) >= 0.25.20
%endif
BuildRequires:  pkgconfig(libxml-2.0)
%if %{with folks_telepathy}
BuildRequires:  pkgconfig(telepathy-glib) >= 0.19.0
%endif
%if %{with folks_zeitgeist}
BuildRequires:  pkgconfig(zeitgeist-2.0)
%endif

%description
libfolks is a library that aggregates people from multiple sources (eg,
Telepathy connection managers) to create metacontacts.

%package -n libfolks
Summary:        Library to create metacontacts from multiple sources
Group:          System/Libraries
Requires:       libfolks-data >= %{version}
Recommends:     %{name}-locale

%description -n libfolks
libfolks is a library that aggregates people from multiple sources (eg,
Telepathy connection managers) to create metacontacts.

%package -n libfolks-data
Summary:        Library to create metacontacts from multiple sources -- Data files
Group:          System/Libraries
Requires(post):   glib2-tools
Requires(postun): glib2-tools

%description -n libfolks-data
libfolks is a library that aggregates people from multiple sources (eg,
Telepathy connection managers) to create metacontacts.

This package provides mandatory data files for the library to work.

%package -n typelib-Folks
Summary:        Library to create metacontacts from multiple sources -- Introspection bindings
Group:          System/Libraries

%description -n typelib-Folks
libfolks is a library that aggregates people from multiple sources (eg,
Telepathy connection managers) to create metacontacts.

This package provides the GObject Introspection bindings for libfolks.

%package -n libfolks-eds
Summary:        Library to create metacontacts from multiple sources -- EDS Backend
Group:          System/Libraries
Supplements:    packageand(libfolks:evolution-data-server)

%description -n libfolks-eds
libfolks is a library that aggregates people from multiple sources (eg,
Telepathy connection managers) to create metacontacts.

%if %{with folks_socialweb}
%package -n libfolks-libsocialweb
Summary:        Library to create metacontacts from multiple sources -- libsocialweb Backend
Group:          System/Libraries
Supplements:    packageand(libfolks:libsocialweb)

%description -n libfolks-libsocialweb
libfolks is a library that aggregates people from multiple sources (eg,
Telepathy connection managers) to create metacontacts.
%endif

%if %{with folks_ofono}
%package -n libfolks-ofono
Summary:        Library to create metacontacts from multiple sources -- ofono Backend
Group:          System/Libraries
Supplements:    packageand(libfolks:ofono)

%description -n libfolks-ofono
libfolks is a library that aggregates people from multiple sources (eg,
Telepathy connection managers) to create metacontacts.
%endif

%if %{with folks_telepathy}
%package -n libfolks-telepathy
Summary:        Library to create metacontacts from multiple sources -- Telepathy Backend
Group:          System/Libraries

%description -n libfolks-telepathy
libfolks is a library that aggregates people from multiple sources (eg,
Telepathy connection managers) to create metacontacts.
%endif

%package tools
Summary:        Library to create metacontacts from multiple sources -- Tools
Group:          Development/Libraries
# the folks-import tool is useful for old pidgin users
Supplements:    packageand(libfolks1:pidgin)


%description tools
libfolks is a library that aggregates people from multiple sources (eg,
Telepathy connection managers) to create metacontacts.

This package provides tools based on libfolks, like an importer for Pidgin
metacontacts.

%package devel
Summary:        Library to create metacontacts from multiple sources -- Development Files
Group:          Development/Libraries
Requires:       libfolks = %{version}
Requires:       libfolks-eds = %{version}
%if %{with folks_socialweb}
Requires:       libfolks-libsocialweb = %{version}
%endif
%if %{with folks_telepathy}
Requires:       libfolks-telepathy = %{version}
%endif
Requires:       typelib-Folks = %{version}

%description devel
libfolks is a library that aggregates people from multiple sources (eg,
Telepathy connection managers) to create metacontacts.


%package locale
Summary: Translations and Locale for package libfolks
Group: System/Localization
Requires: libfolks = %{version}
Provides: libfolks-lang-all = %{version}
BuildArch:  noarch

%description locale
This package provides translations for package %{name}.


%prep
%setup -q

%build

%autogen \
 --enable-vala \
 --disable-static \
 --enable-eds-backend \
%if %{with folks_ofono}
 --enable-ofono-backend \
%else
 --disable-ofono-backend \
%endif
%if %{with folks_telepathy}
 --enable-telepathy-backend \
%else
 --disable-telepathy-backend \
%endif
%if %{with folks_socialweb}
 --enable-socialweb-backend \
%else
 --disable-socialweb-backend \
%endif
 --disable-fatal-warnings \
 --disable-tests \
 #eol

PKG_CONFIG_PATH=`pwd`/folks \
%__make %{?_smp_mflags} V=1

%install
%make_install
find %{buildroot}%{_libdir} -name '*.la' -type f -delete -print
%find_lang folks %{?no_lang_C}

%post -n libfolks -p /sbin/ldconfig

%postun -n libfolks -p /sbin/ldconfig

%post -n libfolks-data
%glib2_gsettings_schema_post

%postun -n libfolks-data
%glib2_gsettings_schema_postun

%post -n libfolks-eds -p /sbin/ldconfig

%postun -n libfolks-eds -p /sbin/ldconfig

%if %{with folks_socialweb}
%post -n libfolks-libsocialweb -p /sbin/ldconfig

%postun -n libfolks-libsocialweb -p /sbin/ldconfig
%endif

%if %{with folks_telepathy}
%post -n libfolks-telepathy -p /sbin/ldconfig

%postun -n libfolks-telepathy -p /sbin/ldconfig
%endif

%files -n libfolks
%defattr(-, root, root)
%license COPYING
%{_libdir}/libfolks.so.%{soversion}*
%dir %{_libdir}/folks
%dir %{_libdir}/folks/%{module_version}
%dir %{_libdir}/folks/%{module_version}/backends
%dir %{_libdir}/folks/%{module_version}/backends/key-file
%{_libdir}/folks/%{module_version}/backends/key-file/key-file.so

%files -n libfolks-data
%defattr(-,root,root)
%{_datadir}/GConf/gsettings/folks.convert
%{_datadir}/glib-2.0/schemas/org.freedesktop.folks.gschema.xml

%files -n typelib-Folks
%defattr(-, root, root)
%{_libdir}/girepository-1.0/FolksEds-0.6.typelib
%if %{with folks_socialweb}
%{_libdir}/girepository-1.0/FolksLibsocialweb-0.6.typelib
%endif
%if %{with folks_telepathy}
%{_libdir}/girepository-1.0/FolksTelepathy-0.6.typelib
%endif
%{_libdir}/girepository-1.0/Folks-0.6.typelib

%files -n libfolks-eds
%defattr(-, root, root)
%{_libdir}/libfolks-eds.so.%{soversion}*
%dir %{_libdir}/folks/%{module_version}/backends/eds
%{_libdir}/folks/%{module_version}/backends/eds/eds.so

%if %{with folks_socialweb}
%files -n libfolks-libsocialweb
%defattr(-, root, root)
%{_libdir}/libfolks-libsocialweb.so.%{soversion}*
%dir %{_libdir}/folks/%{module_version}/backends/libsocialweb
%{_libdir}/folks/%{module_version}/backends/libsocialweb/libsocialweb.so
%endif

%if %{with folks_ofono}
%files -n libfolks-ofono
%defattr(-, root, root)
%dir %{_libdir}/folks/%{module_version}/backends/ofono
%{_libdir}/folks/%{module_version}/backends/ofono/ofono.so
%endif

%if %{with folks_telepathy}
%files -n libfolks-telepathy
%defattr(-, root, root)
%{_libdir}/libfolks-telepathy.so.%{soversion}*
%dir %{_libdir}/folks/%{module_version}/backends/telepathy
%{_libdir}/folks/%{module_version}/backends/telepathy/telepathy.so
%endif

%files tools
%defattr(-, root, root)
%{_bindir}/folks-import
%{_bindir}/folks-inspect

%files devel
%defattr(-, root, root)
%{_includedir}/folks/
%{_libdir}/*.so
%{_libdir}/pkgconfig/*.pc
%{_datadir}/gir-1.0/Folks-0.6.gir
%{_datadir}/gir-1.0/FolksEds-0.6.gir
%if %{with folks_socialweb}
%{_datadir}/gir-1.0/FolksLibsocialweb-0.6.gir
%{_datadir}/vala/vapi/folks-libsocialweb.*
%endif
%if %{with folks_telepathy}
%{_datadir}/gir-1.0/FolksTelepathy-0.6.gir
%{_datadir}/vala/vapi/folks-telepathy.*
%{_datadir}/gir-1.0/TpLowlevel-0.6.gir
%endif
%{_datadir}/vala/vapi/folks.*
%{_datadir}/vala/vapi/folks-eds.*

%files locale -f  %{name}.lang
%defattr(-,root,root,-)

