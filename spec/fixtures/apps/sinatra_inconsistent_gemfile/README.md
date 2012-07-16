This app contains a Gemfile.lock that is missing a dependency
present in Gemfile (rubyzip gem).  It is used to ensure
an error is raised when Gemfile and Gemfile.lock contents
are inconsistent (similar to what would happen if you ran
"bunde install --deployment" with this inconsistency.
