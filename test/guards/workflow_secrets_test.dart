@Tags(['guard'])
library;

// No workflow can print a secret (#35). release.yml's header promises two
// things this guard now holds it to: secrets reach steps only through a
// step's own `env:` (or an action's `with:`), never job- or workflow-wide and
// never pasted into a script; and no script turns on shell tracing, which
// would echo every expanded command — keystore password included — into a
// public log.

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'repo_files.dart';

/// Any use of the `secrets` context inside an expression — `secrets.X`,
/// `secrets['X']`, `toJSON(secrets)` — not only the dotted form (#46).
final _secretExpr = RegExp(r'\$\{\{[^}]*\bsecrets\b');

const _shells = {'bash', 'sh', 'zsh', 'ksh'};

/// True when a shell script turns on tracing: a `set` whose options carry an
/// x flag or `-o xtrace`, or a shell started with such options — including
/// GitHub's own `shell:` template and a `-c` body, which is read as a script
/// in its turn.
bool tracesShell(String script) {
  final words = _shellWords(script);
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    if (w.op || (w.text != 'set' && !_shells.contains(w.text))) continue;
    final args = [
      for (final t in words.skip(i + 1).takeWhile((t) => !t.op)) t.text,
    ];
    if (_optionsTrace(args, shell: w.text != 'set')) return true;
  }
  return false;
}

/// Reads [args] as the options of `set` or of a [shell]. A word that is not
/// an option ends them — so `bash tools/run.sh -x` passes `-x` to a script —
/// and if a `c` flag came first, that word is the shell's script.
bool _optionsTrace(List<String> args, {required bool shell}) {
  var body = false;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (RegExp(r'^--[a-zA-Z][a-zA-Z-]*=').hasMatch(a)) continue;
    if (a == '--rcfile' || a == '--init-file') {
      i++;
      continue;
    }
    if (RegExp(r'^--[a-zA-Z][a-zA-Z-]*$').hasMatch(a)) continue;
    final group = RegExp(r'^([-+])([a-zA-Z]+)$').firstMatch(a);
    if (group == null) return body && tracesShell(a);
    final on = group[1] == '-';
    for (final flag in group[2]!.split('')) {
      if (flag == 'x' && on) return true;
      if (flag == 'c' && shell) body = true;
      // A value left unconsumed (`-O extglob`) would end the options before
      // a `-x` that follows it.
      if (flag == 'o' || flag == 'O') {
        if (++i >= args.length) return false;
        if (flag == 'o' && on && args[i] == 'xtrace') return true;
      }
    }
  }
  return false;
}

class _Word {
  const _Word(this.text, {this.op = false});
  final String text;

  /// A separator that ends a simple command: newline, `;`, `&`, `|`, `(`,
  /// `)` or a backtick.
  final bool op;
}

/// Splits [script] into shell words, the way the shell would: quotes removed
/// (single, double and `$'…'`, with their escapes), a backslash-newline
/// joined, and a `#` that starts a word dropped with the rest of its line.
List<_Word> _shellWords(String script) {
  final s = script;
  final out = <_Word>[];
  final word = StringBuffer();
  var inWord = false;
  void end() {
    if (inWord) out.add(_Word(word.toString()));
    word.clear();
    inWord = false;
  }

  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == r'\' && i + 1 < s.length) {
      if (s[i + 1] != '\n') {
        word.write(s[i + 1]);
        inWord = true;
      }
      i += 2;
    } else if (c == '#' && !inWord) {
      while (i < s.length && s[i] != '\n') {
        i++;
      }
    } else if (c == "'") {
      final close = s.indexOf("'", i + 1);
      final stop = close < 0 ? s.length : close;
      word.write(s.substring(i + 1, stop));
      inWord = true;
      i = stop + 1;
    } else if (c == r'$' && i + 1 < s.length && s[i + 1] == "'") {
      i += 2;
      while (i < s.length && s[i] != "'") {
        if (s[i] == r'\' && i + 1 < s.length) {
          final e = s[i + 1];
          word.write(const {'n': '\n', 't': '\t', 'r': '\r'}[e] ?? e);
          i += 2;
        } else {
          word.write(s[i++]);
        }
      }
      inWord = true;
      i++;
    } else if (c == '"') {
      i++;
      while (i < s.length && s[i] != '"') {
        if (s[i] == r'\' && i + 1 < s.length && '\$`"\\\n'.contains(s[i + 1])) {
          if (s[i + 1] != '\n') word.write(s[i + 1]);
          i += 2;
        } else {
          word.write(s[i++]);
        }
      }
      inWord = true;
      i++;
    } else if (c == ' ' || c == '\t') {
      end();
      i++;
    } else if ('\n;&|()`'.contains(c)) {
      end();
      out.add(_Word(c, op: true));
      i++;
    } else {
      word.write(c);
      inWord = true;
      i++;
    }
  }
  end();
  return out;
}

/// Every way [workflowYaml] could expose a secret, one line per finding.
List<String> secretExposures(String workflowYaml) {
  final doc = loadYaml(workflowYaml);
  if (doc is! YamlMap) return ['not a YAML mapping'];
  final findings = <String>[];
  bool mentionsSecret(Object? node) => _secretExpr.hasMatch('$node');
  String? defaultShell(Object? owner) {
    if (owner is! YamlMap) return null;
    final defaults = owner['defaults'];
    if (defaults is! YamlMap || defaults['run'] is! YamlMap) return null;
    final shell = (defaults['run'] as YamlMap)['shell'];
    return shell == null ? null : '$shell';
  }

  if (mentionsSecret(doc['env'])) findings.add('workflow-level env');
  final workflowShell = defaultShell(doc);
  if (workflowShell != null && tracesShell(workflowShell)) {
    findings.add('workflow default shell traces');
  }
  final jobs = doc['jobs'];
  if (jobs is! YamlMap) return findings;
  for (final entry in jobs.entries) {
    final job = entry.value;
    if (job is! YamlMap) continue;
    if (mentionsSecret(job['env'])) findings.add('${entry.key}: job-level env');
    final jobShell = defaultShell(job);
    if (jobShell != null && tracesShell(jobShell)) {
      findings.add('${entry.key}: default shell traces');
    }
    final steps = job['steps'];
    if (steps is! YamlList) continue;
    for (final step in steps.whereType<YamlMap>()) {
      final id = '${entry.key}/${step['id'] ?? step['name']}';
      final run = step['run'];
      if (run is String) {
        if (_secretExpr.hasMatch(run)) findings.add('$id: secret in run');
        if (tracesShell(run)) findings.add('$id: shell tracing');
      }
      final shell = step['shell'];
      if (shell != null && tracesShell('$shell')) {
        findings.add('$id: shell traces');
      }
    }
  }
  return findings;
}

void main() {
  group('the rule, proven both ways', () {
    const clean = r'''
jobs:
  ship:
    steps:
      - id: keystore
        env:
          PASS: ${{ secrets.PASS }}
        shell: bash --noprofile --norc -eo pipefail {0}
        run: |
          set -euo pipefail
          set +x
          tools/verify_upload_cert.sh --exit-code
          bash tools/run.sh -x
          set -o pipefail
          # set -x here would print the password
          true # set -x here would print it too
          echo "a # set -x inside quotes is not a comment, nor tracing"
          echo a#set -x
          bash -O extglob tools/run.sh -x
          bash --rcfile=/dev/null tools/run.sh -x
          bash -c "tools/run.sh -x" -x
          bash -c 'echo set to -x; echo "don'\''t"'
          sh -c $'echo \'set -x\''
          set +o xtrace
          bash +O extglob tools/run.sh -x
      - id: shell
        shell: bash -O extglob -e {0}
        run: true
''';

    test('secrets in step env with no tracing pass', () {
      final findings = secretExposures(clean);
      expect(
        findings,
        isEmpty,
        reason: 'workflow-secrets: clean line flagged\n${findings.join('\n')}',
      );
    });

    test('every exposure shape is caught', () {
      const dirty = r'''
env:
  A: ${{ secrets.A }}
jobs:
  ship:
    env:
      B: ${{ secrets.B }}
    steps:
      - id: one
        run: echo "${{ secrets.C }}"
      - id: two
        run: |
          set -x
      - id: three
        run: set -euxo pipefail
      - id: four
        run: bash -x tools/thing.sh
      - id: five
        run: |
          true
          set -o xtrace
      - id: six
        run: set -e -x
      - id: seven
        run: set -eu -o xtrace
      - id: eight
        shell: bash -x {0}
        run: echo hi
      - id: nine
        run: echo '${{ toJSON(secrets) }}'
      - id: ten
        run: echo "${{ secrets['X'] }}"
      - id: eleven
        shell: bash --noprofile --norc -eo pipefail -x {0}
        run: echo hi
      - id: twelve
        run: set -euo xtrace
      - id: thirteen
        shell: bash -O extglob -x {0}
        run: echo hi
      - id: fourteen
        shell: bash --rcfile=/dev/null -x {0}
        run: echo hi
      - id: fifteen
        run: bash -c "set -x; true"
      - id: sixteen
        run: bash -c 'set -eux'
      - id: seventeen
        run: bash -c $'true\nset -x'
      - id: eighteen
        run: |
          sh -c "echo \"a # b\"; set -o xtrace"
      - id: nineteen
        run: |
          zsh -ec "
            true
            set -x
          "
      - id: twenty
        shell: bash -eO extglob +O dotglob -x {0}
        run: echo hi
      - id: twentyone
        shell: ksh -c 'set -x; . {0}'
        run: echo hi
      - id: twentytwo
        run: |
          bash --init-file /dev/null \
            -x tools/thing.sh
      - id: twentythree
        run: bash -c $'set \'-x\''
  other:
    defaults:
      run:
        shell: bash -eux {0}
    steps: []
  third:
    defaults:
      run:
        shell: sh -c "set -x; . {0}"
    steps: []
''';
      expect(secretExposures(dirty), [
        'workflow-level env',
        'ship: job-level env',
        'ship/one: secret in run',
        'ship/two: shell tracing',
        'ship/three: shell tracing',
        'ship/four: shell tracing',
        'ship/five: shell tracing',
        'ship/six: shell tracing',
        'ship/seven: shell tracing',
        'ship/eight: shell traces',
        'ship/nine: secret in run',
        'ship/ten: secret in run',
        'ship/eleven: shell traces',
        'ship/twelve: shell tracing',
        'ship/thirteen: shell traces',
        'ship/fourteen: shell traces',
        'ship/fifteen: shell tracing',
        'ship/sixteen: shell tracing',
        'ship/seventeen: shell tracing',
        'ship/eighteen: shell tracing',
        'ship/nineteen: shell tracing',
        'ship/twenty: shell traces',
        'ship/twentyone: shell traces',
        'ship/twentytwo: shell tracing',
        'ship/twentythree: shell tracing',
        'other: default shell traces',
        'third: default shell traces',
      ]);
      expect(secretExposures('defaults:\n  run:\n    shell: bash -x {0}\n'), [
        'workflow default shell traces',
      ]);
    });
  });

  test('no workflow can print a secret', () {
    final workflows = trackedFilesUnder('.github/workflows');
    expect(workflows, contains('.github/workflows/release.yml'));
    final findings = [
      for (final path in workflows)
        for (final f in secretExposures(readFile(path))) '$path: $f',
    ];
    expect(
      findings,
      isEmpty,
      reason: describeOffenders('workflow-secret-exposure', findings),
    );
  });
}
