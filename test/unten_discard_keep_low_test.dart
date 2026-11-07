import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/models/card_model.dart';
import 'package:jass_app/models/game_state.dart';
import 'package:jass_app/models/player.dart';
import 'package:jass_app/utils/monte_carlo.dart';

// Repro aus Feedback-Spiel Jass_Undenufe_Freund2_2026-11-06. Stich 7: der
// Partner (p4) hat nur noch Herz (7/B/D), kann Kreuz nicht bedienen und muss
// abwerfen. In UNDENUFE ist die tiefe 7 ein potenzieller Spaetgewinner
// (schlaegt die 9 im letzten Stich) -> darf NICHT abgeworfen werden. Vorher
// warf _smartDiscard-Fallback nach Punkten ab -> Herz-7 (0 Pkt) raus (Bug).
void main() {
  JassCard c(Suit s, CardValue v) => JassCard(suit: s, value: v, cardType: CardType.french);
  test('Undenufe: Partner behaelt die tiefe Herz-7 (wirft hohe Karte ab)', () {
    final p1 = [ c(Suit.clubs, CardValue.eight), c(Suit.hearts, CardValue.six), c(Suit.hearts, CardValue.nine) ];
    final p2 = [ c(Suit.clubs, CardValue.nine), c(Suit.hearts, CardValue.ten), c(Suit.diamonds, CardValue.eight) ];
    final p3 = [ c(Suit.diamonds, CardValue.ace), c(Suit.spades, CardValue.eight), c(Suit.diamonds, CardValue.seven) ];
    final p4 = [ c(Suit.hearts, CardValue.seven), c(Suit.hearts, CardValue.jack), c(Suit.hearts, CardValue.queen) ];
    final completed = <Trick>[
      Trick(cards: {'p3': c(Suit.clubs, CardValue.six), 'p4': c(Suit.clubs, CardValue.king), 'p1': c(Suit.clubs, CardValue.seven), 'p2': c(Suit.clubs, CardValue.ace)}, winnerId: 'p3', trickNumber: 1),
      Trick(cards: {'p3': c(Suit.spades, CardValue.six), 'p4': c(Suit.spades, CardValue.jack), 'p1': c(Suit.spades, CardValue.nine), 'p2': c(Suit.spades, CardValue.queen)}, winnerId: 'p3', trickNumber: 2),
      Trick(cards: {'p3': c(Suit.diamonds, CardValue.ten), 'p4': c(Suit.diamonds, CardValue.six), 'p1': c(Suit.diamonds, CardValue.jack), 'p2': c(Suit.diamonds, CardValue.king)}, winnerId: 'p4', trickNumber: 3),
      Trick(cards: {'p4': c(Suit.spades, CardValue.seven), 'p1': c(Suit.diamonds, CardValue.queen), 'p2': c(Suit.spades, CardValue.king), 'p3': c(Suit.spades, CardValue.ten)}, winnerId: 'p4', trickNumber: 4),
      Trick(cards: {'p4': c(Suit.hearts, CardValue.ace), 'p1': c(Suit.hearts, CardValue.king), 'p2': c(Suit.hearts, CardValue.eight), 'p3': c(Suit.spades, CardValue.ace)}, winnerId: 'p2', trickNumber: 5),
      Trick(cards: {'p2': c(Suit.clubs, CardValue.jack), 'p3': c(Suit.diamonds, CardValue.nine), 'p4': c(Suit.clubs, CardValue.queen), 'p1': c(Suit.clubs, CardValue.ten)}, winnerId: 'p1', trickNumber: 6),
    ];
    final curCards = [ c(Suit.clubs, CardValue.eight), c(Suit.clubs, CardValue.nine), c(Suit.diamonds, CardValue.ace) ];
    final players=[
      Player(id:'p1',name:'Flavio',position:PlayerPosition.south,hand:p1),
      Player(id:'p2',name:'G1',position:PlayerPosition.east,hand:p2),
      Player(id:'p3',name:'Ansager',position:PlayerPosition.north,hand:p3),
      Player(id:'p4',name:'Partner',position:PlayerPosition.west,hand:p4),
    ];
    final st=GameState(players:players,gameType:GameType.friseur,cardType:CardType.french,
      gameMode:GameMode.unten,trumpSuit:null,phase:GamePhase.playing,
      ansagerIndex:2, friseurPartnerIndex:3, friseurPartnerRevealed:true,
      wishCard: c(Suit.diamonds,CardValue.six),
      currentPlayerIndex:3, completedTricks:completed,
      currentTrickCards:curCards, currentTrickPlayerIds:const ['p1','p2','p3']);
    final chosen=MonteCarloAI.chooseCard(aiPlayer:players[3],state:st);
    // ignore: avoid_print
    print('Partner wirft ab: ' + chosen.displayValue + chosen.displaySuit);
    final isHeart7 = chosen.value == CardValue.seven && chosen.suit == Suit.hearts;
    expect(isHeart7, false, reason: 'Herz-7 (tief/stark in Unten) muss behalten werden');
  });
}
