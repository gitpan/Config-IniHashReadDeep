package Config::IniHashReadDeep; ## Loads INI config as deep hashes

our $VERSION='0.01';

use strict;


use Config::IniHash;


# It is a wrapper using Config::IniHash, but only for loading and it does something
# special; using the entries as paths, delimited by '.' and building a hash tree of it.
#
#
# SYNOPSIS
# ========
# 
#  use Config::IniHashReadDeep;
#  use Data::Dumper;
#
#  my $ini = Config::IniHashReadDeep->new( $file );
#
#  print Dumper($ini);
#
#
# Example ini file:
#
#
#   [main]
#   test=5
#   foo.bar=123
#   foo.more=77
# 
#   [digits]
#   with.counting.000=111
#   with.counting.001=112
#   with.counting.002=113
# 
# 
#   [digitsmore]
#   with.counting.001.foo=111f
#   with.counting.003.bar=111b
#
#
# The example above will print that:
#
#
# 
# 
#   $VAR1 = {                                                                                          
#             'digitsmore' => {                                                                        
#                               'with' => {                                                            
#                                           'counting' => [                                            
#                                                           undef,                                     
#                                                           {                                          
#                                                             'foo' => '111f'
#                                                           },
#                                                           undef,
#                                                           {
#                                                             'bar' => '111b'
#                                                           }
#                                                         ]
#                                         }
#                             },
#             'main' => {
#                         'test' => '5',
#                         'foo' => {
#                                   'bar' => '123',
#                                   'more' => '77'
#                                 }
#                       },
#             'digits' => {
#                           'with' => {
#                                       'counting' => [
#                                                       '111',
#                                                       '112',
#                                                       '113'
#                                                     ]
#                                     }
#                         }
#           };
#
#
#
# Paths
# =====
# The paths used in the ini must be delimited with dotts. But you can set an own delimiter via setting
# 'delimiter' in the constructor.
#
# Numbers
# =======
# If you use numbers in the path elements, it will use an ARRAY instead of an HASH to place the value.
# Please note, that starting with high numbers or leaving gaps in numbers, causes undef entries.
# It will be up to you later to check wether there is a value or not.
#
# Using numbers gives you the possibility to order entries.
#
#
# LICENSE
# =======   
# You can redistribute it and/or modify it under the conditions of LGPL.
# 
# AUTHOR
# ======
# Andreas Hernitscheck  ahernit(AT)cpan.org





# At least it takes a filename. For further values, please have a look into L<Config::IniHash>
# 
# You may set a different 'delimiter'.
sub new { # $inihash (%options)
  my $pkg=shift;
  my $this={};

  bless $this,$pkg;

  my $first=shift;
  my @v=@_;
  my $v={@v};

  my $ini = ReadINI($first,@v);

  $this->{'inihash_flat'} = $ini;

  if ( $v->{'delimiter'} ){
    $this->{'delimiter'} = $v->{'delimiter'};
  }

  

  my $deepini = $this->_unflatten_inihash();

  return $deepini;
}



sub _unflatten_inihash {
  my $this = shift;
  my $ini = $this->{'inihash_flat'};
  my $deepini = {};

  # if not global
  $this->{'STORE'}||={};

  my $delim = $this->{'delimiter'} || '.';

  foreach my $block (keys %$ini) { ## each block in ini

    foreach my $e (keys %{ $ini->{$block} }){

      my $value = $ini->{$block}->{$e};

      ## location holds the direct reference to the final store (right element of the tree)
      my $location = $this->_hash_location_by_path( path => "$block$delim$e" );

      # stores value to location
       ${ $location } = $value;

    }

  }

  $deepini = $this->{'STORE'};

  return $deepini;
}




# builds a recursive hash reference by given path.
# takes hash values like:
# location = reference to formal hashnode
# path = a path like abc.def.more
sub _hash_location_by_path {
  my $this = shift;
  my $v={@_};
  my $path = $v->{'path'} || '';
  my $exec_last = $v->{'exec_last'};
  my $dont_create_undef_entry = $v->{'dont_create_undef_entry'};
  
  my $location = $v->{'location'} || \$this->{'STORE'} ; # ref to a location
  my $pathlocation;

  my $delim = $this->{'delimiter'} || '.';

  ## remove beginning char
  if (index($path,$delim) == 0){
    $path=~ s|^.||;
  }


  my $delimesc = '\\'.$delim;
  

   
   my @path = split( /$delimesc/, $path );

  if (scalar(@path) == 0){ die "path has to less elements" };

  my $first = shift @path; # takes first and shorten path


  if ( scalar( @path ) ){ # more path elements?
 
#     $pathlocation = \${ $location }->{ $first };

      if ($first =~ m/^\d+$/){ ## if it is a digit, make an array
        $pathlocation = \${ $location }->[ $first ];  
      }else{
        $pathlocation = \${ $location }->{ $first };
      }


    # recursive step down the path
    $pathlocation = $this->_hash_location_by_path(  path     => join($delim,@path), 
                                                    location => $pathlocation, 
                                                    remove => $v->{'remove'},
                                                    exec_last => $exec_last,
                                                    dont_create_undef_entry => $dont_create_undef_entry,
                                 );


  }else{ # last path element?

    if ($v->{'remove'}){
      delete ${ $location }->{ $first };
      $dont_create_undef_entry = 1;
    }

    if ($exec_last){
       &$exec_last( location => $location, key => $first );
    }

    ## same line again. it seems to be one too much, but it isnt,
    ## that line creates also an undef value, that exists what 
    ## changes the data. exec subs may work different.
    if ( !$dont_create_undef_entry ){

      if ($first =~ m/^\d+$/){ ## if it is a digit, make an array
         $pathlocation = \${ $location }->[ $first ];
      }else{
        $pathlocation = \${ $location }->{ $first };
      }

       
    }

  }


  



  return $pathlocation;
}




1;