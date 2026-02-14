#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# release-change-data.bash - Required inputs for release change data scripts
#
# These are outputs from versions-and-naming, wired through action templates.
#

VERSION="${VERSION:?VERSION is required - run versions-and-naming first}"
PROJECT_NAME="${PROJECT_NAME:?PROJECT_NAME is required - run versions-and-naming first}"
GIT_TAG="${GIT_TAG:?GIT_TAG is required - run versions-and-naming first}"
