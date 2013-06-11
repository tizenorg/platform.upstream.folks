%define soversion      25
%define module_version 39
%define baseline 0.9

Name:           folks
Version:        0.9.2+3+g2a0168f
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
BuildRequires:  pkgconfig(libsocialweb-client) >= 0.25.20
BuildRequires:  pkgconfig(libxml-2.0)
BuildRequires:  pkgconfig(telepathy-glib) >= 0.19.0
BuildRequires:  pkgconfig(zeitgeist-2.0)

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

%package -n libfolks-libsocialweb
Summary:        Library to create metacontacts from multiple sources -- libsocialweb Backend
Group:          System/Libraries
Supplements:    packageand(libfolks:libsocialweb)

%description -n libfolks-libsocialweb
libfolks is a library that aggregates people from multiple sources (eg,
Telepathy connection managers) to create metacontacts.

%package -n libfolks-ofono
Summary:        Library to create metacontacts from multiple sources -- ofono Backend
Group:          System/Libraries
Supplements:    packageand(libfolks:ofono)

%description -n libfolks-ofono
libfolks is a library that aggregates people from multiple sources (eg,
Telepathy connection managers) to create metacontacts.

%package -n libfolks-telepathy
Summary:        Library to create metacontacts from multiple sources -- Telepathy Backend
Group:          System/Libraries

%description -n libfolks-telepathy
libfolks is a library that aggregates people from multiple sources (eg,
Telepathy connection managers) to create metacontacts.

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
Requires:       libfolks-libsocialweb = %{version}
Requires:       libfolks-telepathy = %{version}
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
 --disable-fatal-warnings \
 #eol

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

%post -n libfolks-libsocialweb -p /sbin/ldconfig

%postun -n libfolks-libsocialweb -p /sbin/ldconfig

%post -n libfolks-telepathy -p /sbin/ldconfig

%postun -n libfolks-telepathy -p /sbin/ldconfig

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
%{_libdir}/girepository-1.0/Folks-0.6.typelib

%files -n libfolks-eds
%defattr(-, root, root)
%{_libdir}/libfolks-eds.so.%{soversion}*
%dir %{_libdir}/folks/%{module_version}/backends/eds
%{_libdir}/folks/%{module_version}/backends/eds/eds.so

%files -n libfolks-libsocialweb
%defattr(-, root, root)
%{_libdir}/libfolks-libsocialweb.so.%{soversion}*
%dir %{_libdir}/folks/%{module_version}/backends/libsocialweb
%{_libdir}/folks/%{module_version}/backends/libsocialweb/libsocialweb.so

%files -n libfolks-ofono
%defattr(-, root, root)
%dir %{_libdir}/folks/%{module_version}/backends/ofono
%{_libdir}/folks/%{module_version}/backends/ofono/ofono.so

%files -n libfolks-telepathy
%defattr(-, root, root)
%{_libdir}/libfolks-telepathy.so.%{soversion}*
%dir %{_libdir}/folks/%{module_version}/backends/telepathy
%{_libdir}/folks/%{module_version}/backends/telepathy/telepathy.so

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
%{_datadir}/vala/vapi/folks.*
%{_datadir}/vala/vapi/folks-eds.*
%{_datadir}/vala/vapi/folks-libsocialweb.*
%{_datadir}/vala/vapi/folks-telepathy.*

%files locale -f  %{name}.lang
%defattr(-,root,root,-)

