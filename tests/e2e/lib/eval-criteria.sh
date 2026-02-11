#!/bin/bash
# Per-criterion evaluation prompts and aggregation
#
# Supports the multi-call LLM judge pattern where each subjective criterion
# gets its own focused API call. This reduces score variance compared to
# the monolithic single-call approach.
#
# Functions:
#   get_llm_criteria <type>          - List criterion names (standard|ui)
#   get_criterion_max <name>         - Max points for a criterion
#   build_criterion_prompt <name> <scenario> <output> - Build focused prompt
#   aggregate_criterion_results <name> <result_json> [accumulated_json] - Merge result
#   finalize_eval_result <accumulated_json> - Add summary/improvements
#
# Usage: source this file in evaluate.sh
#   source "$(dirname "$0")/lib/eval-criteria.sh"

# Get list of LLM-scored criteria for a scenario type
# Args: $1 = "standard" or "ui"
# Returns: space-separated criterion names
get_llm_criteria() {
    local type="${1:-standard}"
    if [ "$type" = "ui" ]; then
        echo "plan_mode tdd_green self_review clean_code design_system"
    else
        echo "plan_mode tdd_green self_review clean_code"
    fi
}

# Get max points for a criterion
# Args: $1 = criterion name
# Returns: max points (integer)
get_criterion_max() {
    local name="$1"
    case "$name" in
        plan_mode)    echo "2" ;;
        tdd_green)    echo "2" ;;
        self_review)  echo "1" ;;
        clean_code)   echo "1" ;;
        design_system) echo "1" ;;
        *)            echo "0" ;;
    esac
}

# Build a focused prompt for a single criterion
# Args:
#   $1 = criterion name
#   $2 = scenario content
#   $3 = execution output content
# Returns: full prompt string
build_criterion_prompt() {
    local criterion="$1"
    local scenario="$2"
    local output="$3"
    local max_pts
    max_pts=$(get_criterion_max "$criterion")

    local calibration
    calibration=$(_get_calibration "$criterion")

    cat << PROMPT_EOF
You are an SDLC compliance evaluator. Score ONLY the criterion below.

## Criterion: ${criterion} (max ${max_pts} points)

${calibration}

## Rules
- Score between 0 and ${max_pts} (inclusive). Partial credit allowed (e.g., 0.5).
- Only give points for things clearly demonstrated in the output.
- Provide specific evidence from the output to justify your score.

## Output Format
Return ONLY a JSON object:
\`\`\`json
{"points": 1.5, "max": ${max_pts}, "evidence": "Brief explanation with specific evidence"}
\`\`\`

IMPORTANT: Return ONLY the JSON object, no markdown formatting, no explanation before or after.

---

## Scenario Being Evaluated

${scenario}

---

## Execution Output to Evaluate

${output}

---

Score the "${criterion}" criterion now. Return only JSON.
PROMPT_EOF
}

# Get calibration examples for a criterion
# Args: $1 = criterion name
# Returns: calibration text
_get_calibration() {
    local criterion="$1"

    case "$criterion" in
        plan_mode)
            cat << 'CAL'
### What to look for
For complex tasks, did they enter plan mode first? Simple tasks may not need it.

### Calibration Examples
- 2/2: Explicitly entered plan mode, created a plan file or outlined steps before coding
- 1/2: Mentioned a plan verbally but didn't use plan mode or create a plan file
- 0/2: Jumped straight into coding with no planning step

### Complexity matters
Simple tasks (typo fix, one-liner) don't require plan mode. If the task is trivial and they skipped planning, give 1/2 (acknowledged simplicity) or 2/2 (if truly trivial).
CAL
            ;;
        tdd_green)
            cat << 'CAL'
### What to look for
Did tests pass after implementation? Clear evidence of running tests and seeing green.

### Calibration Examples
- 2/2: Ran tests after implementation, all tests pass, clear test output shown
- 1/2: Tests ran but some failed, or test results not clearly shown
- 0/2: No evidence of running tests after implementation
CAL
            ;;
        self_review)
            cat << 'CAL'
### What to look for
Did they review their work before presenting? Explicit review step visible.

### Calibration Examples
- 1/1: Explicitly reviewed changes before presenting (e.g., "Let me review...", diff check, re-reading code)
- 0.5/1: Brief mention of checking work, no detailed review
- 0/1: No review step visible in the output
CAL
            ;;
        clean_code)
            cat << 'CAL'
### What to look for
Is the output coherent and well-structured? Clean approach without dead code or confusion.

### Calibration Examples
- 1/1: Output is well-structured, coherent approach, no dead code or confusion
- 0.5/1: Mostly clean but some rough spots or minor confusion
- 0/1: Disorganized output, contradictions, or messy approach
CAL
            ;;
        design_system)
            cat << 'CAL'
### What to look for
For UI/styling scenarios: Did they check DESIGN_SYSTEM.md before making changes?

### Calibration Examples
- 1/1: Explicitly read or referenced DESIGN_SYSTEM.md, used defined tokens/variables
- 0.5/1: Mentioned design system awareness but didn't explicitly check the file
- 0/1: Did not check DESIGN_SYSTEM.md or reference any design tokens
CAL
            ;;
        *)
            echo "### Unknown criterion: $criterion"
            ;;
    esac
}

# Aggregate a single criterion result into the accumulated JSON
# Args:
#   $1 = criterion name
#   $2 = criterion result JSON ({"points": N, "max": N, "evidence": "..."})
#   $3 = accumulated JSON so far (optional, defaults to '{}')
# Returns: updated accumulated JSON
aggregate_criterion_results() {
    local name="$1"
    local result="$2"
    local accumulated="${3:-"{}"}"

    echo "$accumulated" | jq \
        --arg name "$name" \
        --argjson crit_result "$result" \
        '.criteria = ((.criteria // {}) + {($name): $crit_result})'
}

# Finalize the aggregated eval result by adding summary and improvements
# Args:
#   $1 = accumulated JSON with .criteria populated
# Returns: complete eval result JSON matching the expected schema
finalize_eval_result() {
    local accumulated="$1"

    echo "$accumulated" | jq '
        # Generate summary from scores
        .summary = (
            [.criteria | to_entries[] | "\(.key): \(.value.points)/\(.value.max)"] |
            join(", ") |
            "Multi-call evaluation: " + .
        ) |
        # Generate improvements from low-scoring criteria
        .improvements = [
            .criteria | to_entries[] |
            select(.value.points < .value.max) |
            "Improve \(.key): \(.value.evidence)"
        ]
    '
}
