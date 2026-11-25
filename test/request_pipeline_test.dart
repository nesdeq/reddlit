import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reddlit/services/request_pipeline.dart';

const _page = '<div id="siteTable"></div>';

void main() {
  testWidgets('requests wait out the Retry-After reddit sends, and only that',
      (tester) async {
    DateTime now() => tester.binding.clock.now();
    final dispatched = <DateTime>[];
    final pipeline = RequestPipeline.withClient(
      MockClient((request) async {
        dispatched.add(now());
        return http.Response(_page, 200, headers: {
          'retry-after': request.url.path == '/r/slow/' ? '3' : '0',
        });
      }),
      now: now,
    );
    Future<String?> get(String sub) =>
        pipeline.getHtml(Uri.https('old.reddit.com', '/r/$sub/'));

    await Future.wait([get('a'), get('b')]);
    expect(dispatched[1].difference(dispatched[0]), Duration.zero);

    await get('slow');
    final next = get('c');
    await tester.pump(const Duration(seconds: 3));
    await next;
    expect(dispatched[3].difference(dispatched[2]), const Duration(seconds: 3));
  });

  test('a transient failure is retried once', () async {
    final statuses = [503, 200, 503, 503, 404];
    var requests = 0;
    final pipeline = RequestPipeline.withClient(MockClient((_) async {
      final status = statuses[requests++];
      return http.Response(status == 200 ? _page : '', status);
    }));
    Future<String?> get(String sub) =>
        pipeline.getHtml(Uri.https('old.reddit.com', '/r/$sub/'));

    expect(await get('recovers'), _page);
    expect(requests, 2);
    expect(await get('stays-down'), isNull);
    expect(requests, 4);
    expect(await get('missing'), isNull);
    expect(requests, 5);
  });

  test('no more requests are in flight than a browser would open', () async {
    final pending = <Completer<http.Response>>[];
    final pipeline = RequestPipeline.withClient(
        MockClient((_) => (pending..add(Completer())).last.future));
    final all = [
      for (var i = 0; i < RequestPipeline.maxConcurrent + 2; i++)
        pipeline.getHtml(Uri.https('old.reddit.com', '/r/s$i/')),
    ];
    await pumpEventQueue();
    expect(pending, hasLength(RequestPipeline.maxConcurrent));

    for (var i = 0; i < all.length; i++) {
      pending[i].complete(http.Response(_page, 200));
      await pumpEventQueue();
    }
    expect(await Future.wait(all), everyElement(_page));
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
      return http.Response(_page, 200);
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
          : http.Response(_page, 200);
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
