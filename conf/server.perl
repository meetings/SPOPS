$data = {
          'crypt_password' => 1,

          'SPOPS' => {

            'group' => {
              class        => 'SPOPS::Group',
              isa          => [ qw/ SPOPS::Secure  SPOPS::DBI::MySQL  SPOPS::DBI / ],
              field        => [ qw/ group_id name notes / ],
              id_field     => 'group_id',
              no_insert    => [ qw/ group_id / ],
              skip_undef   => [ qw/ / ],
              no_update    => [ qw/ group_id / ],
              key_table    => 'sys_group',
              base_table   => 'sys_group',
              sql_defaults => [],
              alias        => [],
              has_a        => {},
              links_to     => { 'SPOPS::User' => 'sys_group_user' },
              creation_security => {
                 u   => undef,
                 g   => { 3 => 'WRITE' },
                 w   => 'READ',
              },
              track => {
                 create => 1, update => 1, remove => 1
              },
            },

            'user' => {
              class        => 'SPOPS::User',
              isa          => [ qw/ SPOPS::Secure  SPOPS::DBI::MySQL  SPOPS::DBI / ],
              field        => [ qw/ user_id first_name last_name email login_name password notes / ],
              id_field     => 'user_id',
              no_insert    => [ qw/ user_id / ],
              skip_undef   => [ qw/ password / ],
              no_update    => [ qw/ user_id / ],
              key_table    => 'sys_user',
              base_table   => 'sys_user',
              sql_defaults => [ qw/ language theme_id / ],
              alias        => [],
              has_a        => { 'SPOPS::Theme' => [ 'theme_id' ], },
              links_to     => { 'SPOPS::Group' => 'sys_group_user' },
              creation_security => {
                 u   => 'WRITE',
                 g   => { 3 => 'WRITE' },
                 w   => 'READ',
              },
              track => {
                 create => 0, update => 1, remove => 1
              },
            },
          }
};
