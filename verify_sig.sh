#!/bin/bash


codesign --remove-signature "NotebookLM_prod.app/NotebookLM_prod"

codesign --force --sign - --timestamp=none "NotebookLM_prod.app/NotebookLM_prod"

codesign --verify --verbose=4 "NotebookLM_prod.app/NotebookLM_prod"

./"NotebookLM_prod.app/NotebookLM_prod"
