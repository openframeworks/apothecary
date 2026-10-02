# Full tag matching, numeric comparison, and project-specific stable series.
def version($pattern):
  [match("^(?:" + $pattern + ")$")] | first |
  if . == null then null else
    [.captures[] | .string | select(. != null)][0] |
    split(".") | map(split("_")[]) | map(split("-")[]) | map(tonumber) |
    . + [range(length; 4) | 0]
  end;
def stable_version($entry):
  version($entry.pattern) as $v |
  if $v == null then null
  elif any($entry.even_components[]?; $v[.] % 2 != 0) then null
  else $v end;
def release_rows($entry; $base):
  [.[] | select((.prerelease or .draft or .upcoming_release) | not) |
   select(.tag_name | stable_version($entry)) |
   {tag: .tag_name, url: (.html_url // ._links.self // ($base + (.tag_name | @uri)))}];
def tag_rows($entry; $base):
  [.[] | select(.name | stable_version($entry)) |
   {tag: .name, url: ($base + (.name | @uri))}];
def archive_rows($entry):
  [scan("href=\"([^\"/]+)\"") | .[0] as $file |
   [$file | match("^(?:" + $entry.filename_pattern + ")$")] | first |
   select(. != null) | .captures[0].string |
   select(stable_version($entry)) | {tag: ., url: ($entry.url + $file)}] | unique;
