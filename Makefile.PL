use 5.008008;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'RPSL::Parser',
    VERSION_FROM => 'lib/RPSL/Parser.pm',    # finds $VERSION
    PREREQ_PM    => {},                      # e.g., Module::Name => 1.1
    (
        $] >= 5.005
        ?    ## Add these new keywords supported since 5.005
          (
            ABSTRACT_FROM =>
              'lib/RPSL/Parser.pm',    # retrieve abstract from module
            AUTHOR => 'Luis Motta Campos <lmc@bitbistro.com>'
          )
        : ()
    ),
);
