#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# manifest-file-kinds.bash - What may live in a manifests tree, and what it is
#
# A manifests tree holds .yaml manifests and their modifier files, and nothing
# else. Dotfiles are the one exception: they are pruned from every walk here
# rather than rejected, because macOS scatters .DS_Store through any directory
# it has been browsed in and that is not the author's doing.
#
# A modifier file changes the manifest it sits beside rather than being one.
# It is <manifest>.yaml.<type>-<desc>, where <type> is one of
# MANIFEST_MODIFIER_TYPES below:
#
#   yq-merge-yaml        yq patch: a YAML fragment, merged into the target
#   yq-expression-list   yq patch: one yq expression per line, applied in turn
#   yq-from-file         yq patch: one yq expression, may span lines, pipe-joined
#
# and <desc> is a description of lower-case letters, digits and hyphens with at
# least one letter or digit, which is how the author controls the order a
# target's modifiers apply in, and says why each is there.
#
# That charset is not only house style. Excluding '.' is what stops a modifier
# filename also matching '*.yaml', which is the shorthand the whole build uses
# for "manifest". Allow a description like 'keelson.yaml' and every such walk
# quietly treats a modifier as a manifest.
#
# Adding a type is one entry in MANIFEST_MODIFIER_TYPES: the find walks, the
# classifier and the messages are all built from it. The step that acts on the
# new type is its own, selecting it by MANIFEST_FILE_MODIFIER_TYPE.
#
# The grammar lives here rather than in any one caller so that every level of
# the build agrees on what a modifier file is. Where the levels differ is in how
# much they check: this library answers "what is this file" and "does its
# target exist", both of which need only the filename and the filesystem.
# Anything that depends on the target's CONTENT belongs to the env/RP step
# acting on that type, which is the only place that content is final rather than still full
# of unresolved tokens.
#
# There are only two questions to ask of a directory, and a function for each:
# what is in here that we do not accept, and what is in here that we want.
#
#   manifest_files_find_packageable   - what we want
#   manifest_files_find_unpackageable - what we do not accept
#   manifest_dir_reject_unpackageable - report what we do not accept, and fail
#   manifest_file_classify            - judge one file by name and filesystem
#   manifest_tree_validate            - both questions over a merged tree
#   manifest_rules_explain            - state the rules once, before exiting
#
#
# WHICH ENTRY POINT, AND WHY THEY DIFFER
#
# A contributor directory (src/kubernetes, additional-manifests) gets
# manifest_dir_reject_unpackageable, which checks shape only. A merged tree
# (combined) gets manifest_tree_validate, which checks shape AND classifies.
#
# That asymmetry is deliberate and load-bearing. A modifier contributed by one
# directory may target a manifest contributed by another, so "does this
# modifier have its target beside it" is unanswerable until the trees are
# merged.
# Running the full validation over a contributor directory would fail projects
# that are perfectly correct.
#
# Shape is different: it is a property of the filename alone, so it can be
# judged wherever the file sits. It is judged early precisely so the error
# names the path the author actually wrote rather than some path under the
# build output.
#
# Requires lib/log.bash.
#
# shellcheck disable=SC2034  # MANIFEST_* set here, consumed by sourcing scripts
# shellcheck disable=SC2254  # case patterns below are globs on purpose

# The shapes a filename may take, defined ONCE. The find walks and the
# classifier below are both built from these, so the walk that says "this file
# has no acceptable shape" and the classifier that says why cannot disagree
# about what the shapes are.
#
# Shape is all a glob can judge. The other two modifier rules - a description
# carrying a letter or digit, and a target manifest existing beside it - are
# not expressible here, which is why matching a shape means "looks right"
# rather than "is right" and manifest_file_classify still has work to do.
MANIFEST_FILE_GLOB='*.yaml'
MANIFEST_MODIFIER_TYPES=(yq-merge-yaml yq-expression-list yq-from-file)

# Derived at source time from the two definitions above: find arguments for a
# positive shape match, the type list as it reads in an error message, and the
# types longest first, which is the order the classifier tries them in so a
# type that is a prefix of another can never claim its files.
MANIFEST_SHAPE_FIND_ARGS=(-name "${MANIFEST_FILE_GLOB}")
MANIFEST_MODIFIER_TYPES_LIST=""
for _manifest_modifier_type in "${MANIFEST_MODIFIER_TYPES[@]}"; do
  MANIFEST_SHAPE_FIND_ARGS+=(-o -name "${MANIFEST_FILE_GLOB}.${_manifest_modifier_type}-*")
  if [[ -n "${MANIFEST_MODIFIER_TYPES_LIST}" ]]; then
    MANIFEST_MODIFIER_TYPES_LIST="${MANIFEST_MODIFIER_TYPES_LIST}, "
  fi
  MANIFEST_MODIFIER_TYPES_LIST="${MANIFEST_MODIFIER_TYPES_LIST}${_manifest_modifier_type}"
done
MANIFEST_MODIFIER_TYPES_LONGEST_FIRST=()
while IFS= read -r _manifest_modifier_type; do
  MANIFEST_MODIFIER_TYPES_LONGEST_FIRST+=("${_manifest_modifier_type}")
done < <(printf '%s\n' "${MANIFEST_MODIFIER_TYPES[@]}" \
  | awk '{ print length($0) "\t" $0 }' | LC_ALL=C sort -k1,1nr -k2,2 | cut -f2)
unset _manifest_modifier_type

# Dotfiles are pruned from every walk here. -prune rather than a name filter
# because a hidden DIRECTORY holds files whose own names look perfectly
# ordinary, and only pruning stops the descent. The explicit -print is
# load-bearing: find adds an implicit print only when the expression has no
# action other than -prune, so without it every pruned entry is printed too,
# which is the exact opposite of the intent. -mindepth 1 is defensive, keeping
# the starting directory itself from being tested and pruning the whole walk
# away.

# Walk a tree for files shaped like something that belongs: the manifests and
# modifiers. What actually gets packaged, and what gets counted.
#
# Newline-delimited, with no NUL-delimited twin. The shapes constrain every
# name to end in .yaml or .yaml.<type>-<desc>, and the other consumers of
# this list - `wc -l` for counts and `zip -@` for packaging - are newline-based
# anyway, so a NUL variant would harden one path while leaving those exposed. A
# filename containing a newline splits into pieces that no longer exist, so a
# copy fails loudly under set -e rather than copying the wrong thing quietly.
# Such a name is not supported, and failing is the correct outcome.
#
# Usage: manifest_files_find_packageable <directory>
manifest_files_find_packageable() {
  find "${1}" -mindepth 1 -name '.*' -prune -o -type f \
    \( "${MANIFEST_SHAPE_FIND_ARGS[@]}" \) -print
}

# Walk a tree for files shaped like nothing that belongs. The exact complement
# of the walk above, so between them they see every non-dotfile once.
#
# This is what makes a stray README a named build failure rather than a file
# that quietly did not get packaged. A build that only ever looked for what it
# wanted could not tell the difference.
#
# Usage: manifest_files_find_unpackageable <directory>
manifest_files_find_unpackageable() {
  find "${1}" -mindepth 1 -name '.*' -prune -o -type f \
    ! \( "${MANIFEST_SHAPE_FIND_ARGS[@]}" \) -print
}

# State what a manifests tree may hold. For the caller to log once on its way
# out, however many directories offended, rather than repeating it per
# directory.
#
# Usage: manifest_rules_explain
manifest_rules_explain() {
  log_error "A manifests tree may hold only .yaml manifests and their"
  log_error ".yaml.<type>-<desc> modifier files, type one of: ${MANIFEST_MODIFIER_TYPES_LIST}."
  log_error "Dotfiles are ignored."
}

# Internal: log a heading and one indented line per rejection.
# Usage: manifest_log_rejections <heading> <entry>...
manifest_log_rejections() {
  local heading="${1}"
  shift
  log_error "${heading}"
  local entry
  for entry in "$@"; do
    log_error "  ${entry}"
  done
}

# Report every file in a directory whose NAME disqualifies it, and say so.
#
# The companion to copying only the good stuff: a contributor directory is
# checked for what it must not contain, then only what it should contain is
# taken from it. Without the check, filtering at copy time would make a stray
# file vanish silently instead of being named.
#
# Shape only, deliberately. See WHICH ENTRY POINT in the header: a modifier
# here may target a manifest another contributor supplies, so its target cannot be
# looked for until the trees are merged.
#
# Usage: manifest_dir_reject_unpackageable <directory>
# Returns: 0 if the directory holds nothing unacceptable, 1 otherwise with
#          every offender already logged
manifest_dir_reject_unpackageable() {
  local dir="${1}"
  local file rejected=()

  while IFS= read -r file; do
    if manifest_file_classify "${file}"; then
      # The walk found no acceptable shape and the classifier accepted it
      # anyway, so the two are built from the same definitions and have still
      # managed to disagree. That is a bug here, not in the tree being
      # checked, and it must never surface as a rejection with a blank reason.
      MANIFEST_FILE_REASON="internal error: shape walk and classifier disagree about this file"
    fi
    rejected+=("${file#"${dir}"/}: ${MANIFEST_FILE_REASON}")
  done < <(manifest_files_find_unpackageable "${dir}")

  if [[ ${#rejected[@]} -eq 0 ]]; then
    return 0
  fi

  manifest_log_rejections "Files in ${dir} that cannot be packaged:" \
    "${rejected[@]+"${rejected[@]}"}"
  return 1
}

# Judge one file by its name and the filesystem beside it.
#
# Called from both directions: on a file a shape walk accepted, to say what it
# is and whether its deeper rules hold, and on a file a shape walk rejected, to
# say why. That second use is why the "no acceptable shape" reason exists here
# rather than at the walk.
#
# Usage: manifest_file_classify <path>
# Returns: 0 and sets MANIFEST_FILE_KIND to manifest or modifier; for a
#            modifier, MANIFEST_FILE_MODIFIER_TYPE, MANIFEST_FILE_MODIFIER_DESC
#            and MANIFEST_FILE_MODIFIER_TARGET are set too
#          1 and sets MANIFEST_FILE_REASON to a message explaining the
#            rejection, ready for a caller to prefix with the relative path
#
# The target-exists check looks in the file's own directory, so a modifier never
# finds a same-named manifest elsewhere in the tree. It is therefore only
# meaningful on a merged tree; see WHICH ENTRY POINT in the header.
manifest_file_classify() {
  # Ranges in glob patterns collate by locale, and under most of them [a-z]
  # includes upper case, so a negated [!a-z0-9-] would accept 'Keelson'.
  # Function-scoped so the whole classifier matches ASCII deterministically
  # without changing the locale for anything the caller does.
  local LC_ALL=C
  local path="${1}"
  local base="${path##*/}"
  local target rest modifier_type

  MANIFEST_FILE_KIND=""
  MANIFEST_FILE_MODIFIER_TYPE=""
  MANIFEST_FILE_MODIFIER_DESC=""
  MANIFEST_FILE_MODIFIER_TARGET=""
  MANIFEST_FILE_REASON=""

  # A known modifier type first: a description ending in .yaml would
  # otherwise be mistaken for a manifest.
  for modifier_type in "${MANIFEST_MODIFIER_TYPES_LONGEST_FIRST[@]}"; do
    case "${base}" in
      ${MANIFEST_FILE_GLOB}."${modifier_type}"-*)
        target="${base%%."${modifier_type}"-*}"
        MANIFEST_FILE_MODIFIER_TYPE="${modifier_type}"
        MANIFEST_FILE_MODIFIER_DESC="${base#"${target}.${modifier_type}-"}"
        break
        ;;
    esac
  done

  if [[ -n "${MANIFEST_FILE_MODIFIER_TYPE}" ]]; then
    # Lower-case letters, digits and hyphens only, with at least one
    # letter or digit. Excluding '.' is what keeps a modifier from also
    # matching '*.yaml': a description like 'keelson.yaml' is the name an
    # author reaches for so their editor highlights the fragment, and it
    # would make the file indistinguishable from a manifest to every
    # -name '*.yaml' walk in the build.
    case "${MANIFEST_FILE_MODIFIER_DESC}" in
      *[!a-z0-9-]*)
        MANIFEST_FILE_REASON="description after '${MANIFEST_FILE_MODIFIER_TYPE}-' may hold only lower-case letters, digits and hyphens"
        return 1
        ;;
    esac
    case "${MANIFEST_FILE_MODIFIER_DESC}" in
      *[a-z0-9]*) ;;
      *)
        MANIFEST_FILE_REASON="description after '${MANIFEST_FILE_MODIFIER_TYPE}-' must contain at least one letter or digit"
        return 1
        ;;
    esac
    if [[ ! -f "$(dirname "${path}")/${target}" ]]; then
      MANIFEST_FILE_REASON="modifier has no target manifest '${target}' beside it"
      return 1
    fi
    MANIFEST_FILE_MODIFIER_TARGET="${target}"
    MANIFEST_FILE_KIND="modifier"
    return 0
  fi

  case "${base}" in
    ${MANIFEST_FILE_GLOB})
      MANIFEST_FILE_KIND="manifest"
      return 0
      ;;
    ${MANIFEST_FILE_GLOB}.*)
      rest="${base#*.yaml.}"
      MANIFEST_FILE_REASON="unknown modifier type in '.yaml.${rest}'; expected .yaml.<type>-<desc> with type one of: ${MANIFEST_MODIFIER_TYPES_LIST}"
      return 1
      ;;
  esac

  # Prose, deliberately not built from MANIFEST_FILE_GLOB: deriving it would
  # render the rule as '*.yaml', which is how find sees it and not how anyone
  # reading a build log wants it described.
  MANIFEST_FILE_REASON="not a manifest (.yaml) or a modifier (.yaml.<type>-<desc>)"
  return 1
}

# Validate a merged tree, reporting every offender rather than the first.
#
# Two walks, one per question. What is not acceptable is reported by
# manifest_dir_reject_unpackageable. What looks acceptable is then classified,
# because looking right is not the same as being right: a description with no
# letter or digit in it, and a modifier whose target manifest is missing, both
# match a shape perfectly.
#
# For a MERGED tree only. A contributor directory takes
# manifest_dir_reject_unpackageable instead; see WHICH ENTRY POINT in the
# header for why running this over one would fail correct projects.
#
# Usage: manifest_tree_validate <directory>
# Returns: 0 if the tree holds only manifests and valid modifiers
#          1 if anything was rejected, with every offender already logged
# Sets: MANIFEST_TREE_MANIFEST_COUNT and MANIFEST_TREE_MODIFIER_COUNT
#
# What "empty" means is deliberately left to the caller, which is why the two
# counts are reported separately rather than reduced to a verdict here. A tree
# holding nothing and a tree holding only files it should not are different
# problems, and a tree that is legitimately empty is normal in some parts of
# the build and fatal in others.
manifest_tree_validate() {
  local tree="${1}"
  local clean=true

  MANIFEST_TREE_MANIFEST_COUNT=0
  MANIFEST_TREE_MODIFIER_COUNT=0

  manifest_dir_reject_unpackageable "${tree}" || clean=false

  local file rejected=()
  while IFS= read -r file; do
    if ! manifest_file_classify "${file}"; then
      rejected+=("${file#"${tree}"/}: ${MANIFEST_FILE_REASON}")
      continue
    fi
    case "${MANIFEST_FILE_KIND}" in
      manifest) MANIFEST_TREE_MANIFEST_COUNT=$((MANIFEST_TREE_MANIFEST_COUNT + 1)) ;;
      modifier) MANIFEST_TREE_MODIFIER_COUNT=$((MANIFEST_TREE_MODIFIER_COUNT + 1)) ;;
    esac
  done < <(manifest_files_find_packageable "${tree}")

  if [[ ${#rejected[@]} -gt 0 ]]; then
    clean=false
    manifest_log_rejections "Modifier files in ${tree} that cannot be used:" \
      "${rejected[@]+"${rejected[@]}"}"
  fi

  ${clean}
}
