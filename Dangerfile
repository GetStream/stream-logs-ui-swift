pr_body = github.pr_body
pr_labels = github.pr_labels

if pr_body.include?('#skip_danger')
  message('Skipping Danger due to skip_danger tag')
  return
end

# Make it more obvious that a PR is a work in progress and shouldn't be merged yet
has_wip_labels = pr_labels.any? { |label| label =~ /(WIP|Help Wanted)/ }
if github.pr_json.draft || has_wip_labels
  message('Skipping Danger since the Pull Request is classed as `Draft`/`Work In Progress`')
  return
end

# Don't forget to tick the required checkboxes in a PR description
missed_checkboxes = pr_body.each_line.any? { |line| line.include?('[ ]') && line.include?('(required)') }
warn('Please be sure to complete the `Contributor Checklist` in the Pull Request description') if missed_checkboxes

# Warn when there is a big PR.
warn('Big PR') if git.lines_of_code > 500

# Mainly to encourage writing up some reasoning about the PR, rather than just leaving a title.
warn('Please provide a summary in the Pull Request description') if pr_body.length < 3 && git.lines_of_code > 50

# Check all commits have correct format. Disable the length rule, since it's hardcoded to 50 and GitHub has the limit 80
commit_lint.check(disable: [:subject_length])
