use 5.008008;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'RPSL::Parser',
    VERSION_FROM => 'lib/RPSL/Parser.pm',
    PREREQ_PM    => {},
    (   $] >= 5.005
        ? ( ABSTRACT_FROM => 'lib/RPSL/Parser.pm',
            AUTHOR        => 'Luis Motta Campos <lmc@bitbistro.com>'
            )
        : ()
    ),
);
