import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reddlit/services/request_pipeline.dart';

void main() {
  testWidgets('requests that wait together still dispatch a full minGap apart',
      (tester) async {
    DateTime now() => tester.binding.clock.now();
    final dispatched = <DateTime>[];
    final pipeline = RequestPipeline.withClient(
      MockClient((_) async {
        dispatched.add(now());
        return http.Response('<div id="siteTable"></div>', 200);
      }),
      now: now,
    );

    final done = Future.wait([
      for (final sub in ['a', 'b', 'c'])
        pipeline.getHtml(Uri.https('old.reddit.com', '/r/$sub/')),
    ]);
    await tester.pump(RequestPipeline.minGap * 3);
    await done;

    expect(dispatched, hasLength(3));
    for (var i = 1; i < dispatched.length; i++) {
      expect(dispatched[i].difference(dispatched[i - 1]),
          greaterThanOrEqualTo(RequestPipeline.minGap));
    }
  });

  test('a redirect to a raw UTF-8 path is followed to that path', () async {
    final requested = <String>[];
    final pipeline = RequestPipeline.withClient(MockClient((request) async {
      requested.add(request.url.path);
      expect(request.followRedirects, isFalse);
      if (request.url.path == '/comments/abc/') {
        // dart:io hands the header's UTF-8 bytes over decoded as latin1.
        return http.Response('', 301, headers: {
          'location': latin1.decode(utf8.encode('/r/de/comments/abc/über/')),
        });
      }
      return http.Response('<div id="siteTable"></div>', 200);
    }));

    final body =
        await pipeline.getHtml(Uri.https('old.reddit.com', '/comments/abc/'));

    expect(body, isNotNull);
    expect(requested, ['/comments/abc/', '/r/de/comments/abc/%C3%BCber/']);
  });

  test('getRedirect reports where one request points, without following', () async {
    final requested = <String>[];
    final pipeline = RequestPipeline.withClient(MockClient((request) async {
      requested.add(request.url.path);
      return request.url.path == '/r/x/s/tok'
          ? http.Response('', 307, headers: {
              'location': 'https://www.reddit.com/r/x/comments/y/z/?share_id=1',
            })
          : http.Response('<div id="siteTable"></div>', 200);
    }));

    expect(
      (await pipeline.getRedirect(Uri.https('www.reddit.com', '/r/x/s/tok')))
          .toString(),
      'https://www.reddit.com/r/x/comments/y/z/?share_id=1',
    );
    expect(await pipeline.getRedirect(Uri.https('www.reddit.com', '/r/x/')),
        isNull);
    expect(requested, ['/r/x/s/tok', '/r/x/']);
  });

  test('a redirect loop ends in failure', () async {
    var requests = 0;
    final pipeline = RequestPipeline.withClient(MockClient((request) async {
      requests++;
      return http.Response('', 302, headers: {'location': '/loop/'});
    }));

    expect(await pipeline.getHtml(Uri.https('old.reddit.com', '/loop/')), isNull);
    expect(requests, RequestPipeline.maxRedirects + 1);
  });
}
