$(document).ready(function(){
  $('a').smoothScroll();
});
// could use http://cpettitt.github.io/project/dagre-d3/latest/demo/interactive-demo.html for graph
var app = angular.module('PreferentialDemo', ['pascalprecht.translate']);
app.config(function ($translateProvider) {
  //$translateProvider.useSanitizeValueStrategy(null);
  $translateProvider.translations('en', {
    LANGUAGE: 'Language',
    EXAMPLES: 'Examples',
    DATA: 'Data',
    VOTES: 'Votes',
    SCORES: 'Scores',
    ONE_TO_ONE_SCORES : 'One to one scores (or pairs)',
    GRAPH: 'Graph',
    NO_CONTRADICTION_GRAPH: 'The no-contradiction graph',
    RESULT: 'Results',
    RANKING : 'Ranking',

    BTN_PARSE_VOTES :  'Parse the votes',
    BTN_COMPUTE_SCORES :  'Compute one-to-one scores',
    BTN_ADD_TO_GRAPH :  'Add one pair to the graph',
    BTN_FIND_SOURCE :  'Extract a winner',

    P_PREFERENCES :  'Each person vote by expressing preference.',
    P_A_OVER_B :  'means the voter prefers A to B.',
    P_C_EQUAL_D : 'means the voter likes them the same.',
    P_E_CD_A :'means E is the first choice, then C and D are the second choice and A would be the worst.',
    P_123_MEANS :'means 123 people have expressed the "A and then B" vote.',
    P_EACH_LINE :'Each line corresponds to a different preferential vote with the number of people voting it.',

    P_EXTRACT_VOTES : 'We extract the votes from the provided text.',

    P_POSSIBLE_CONFRONTATIONS : 'Then we imagine all possible confrontation between two candidates X and Y.\
    For each vote we count if the voter prefers X to Y of the opposite.\
    This gives us a score for X>Y and another for Y>X.',
    P_25_OVER_12 : 'If 25 prefer X to Y and 12 prefer Y to X, we create a pair X > Y with the score 25-12=13.',
    P_10_OVER_12 : 'If 10 prefer X to Y and 12 prefer Y to X, we create a pair Y > X with the score 12-10=2.',
    P_RANKING_PAIRS : 'Then, we sort X Y pairs greater scores first.',

    P_BUILD_GRAPH : 'We build a graph by adding pairs from the strongest to the weakest, unless it creates a cycle (displayed in red and then removed.',
    P_INTUITION : 'The intuition is that a cycle is a contradiction. A wins over B who wins over C who wins over A makes it impossible to find a clear winner.',
    P_CHOOSE_STRONG : 'In this situation, this method CHOOSES to ignore weak wins to favorise strong wins.',

    P_EXTRACT_WINNER: 'The result is extracted by finding a candidate that has only wins (positive scores against all opponents). \
    We successively remove all such nodes.',
    P_CONDORCET: 'This method guarantees that if a candidate wins all one to one contests, he wins (this a called a Condorcet winner).',
    P_PERCENTAGE_GRAPH : 'The % graph shows the percentage of voters who prefers the candidate. This is used to suggest the amplitude of the victory.'
  });
  $translateProvider.translations('fr', {
    LANGUAGE: 'Langue',
    EXAMPLES: 'Exemples',
    DATA: 'Données',
    VOTES: 'Votes',
    SCORES: 'Scores',
    ONE_TO_ONE_SCORES : 'Score pour chaque couple de candidats (ou "paires")',
    GRAPH: 'Graphe',
    NO_CONTRADICTION_GRAPH: 'Le graphe sans contradiction',
    RESULT: 'Résultats',
    RANKING : 'Classement',

    BTN_PARSE_VOTES :  'Extraire les votes',
    BTN_COMPUTE_SCORES :  'Calculer les résultats paire par paire',
    BTN_ADD_TO_GRAPH :  'Ajouter une paire au graphe',
    BTN_FIND_SOURCE :  'Extraire un gagnant',

    P_PREFERENCES :  'Chaque électeur exprime ses préférences.',
    P_A_OVER_B :  'signifie que l\'électeur préfère A à B.',
    P_C_EQUAL_D : 'signifie que l\'électeur les situe au même niveau.',
    P_E_CD_A :'signifie que l\'électeur préfère E puis C et D indifféremment et enfin A.',
    P_123_MEANS :'signifie que 123 personnes ont exprimé le vote "A puis B".',
    P_EACH_LINE :'Chaque ligne correspond à un ordre de préférence et au nombre d\'électeurs l\'ayant choisi.',

    P_EXTRACT_VOTES : 'On extrait les votes à partir du texte fourni.',

    P_POSSIBLE_CONFRONTATIONS : 'On imagine toutes les confrontations entre 2 candidats X and Y.\
    Pour chaque électeur, on compte s\'il préfère X à Y, le contraire ou si ça lui est égal.\
    Cela nous fournit un nombre de X>Y et un autre de Y>X.',
    P_25_OVER_12 : 'Si 25 personnes préfèrent X à Y et 12 prefèrent Y à X, on crée la paire X > Y avec le score de 25-12=13.',
    P_10_OVER_12 : 'Si 10 personnes préfèrent X à Y et 12 prefèrent Y à X, on crée la paire Y > X avec le score de 12-10=2.',
    P_RANKING_PAIRS : 'On classe ensuite chaque paire X Y du plus grand score au plus petit.',

    P_BUILD_GRAPH : 'On construit un graphe en commençant avec les paires à gros score. Si une paire crée un cycle (en rouge), on ne l\'ajoute pas',
    P_INTUITION : 'L\'intuition est qu\'un cycle est une contradiction. A bat B qui bat C qui bat A, cela rend difficile de déclarer un gagnant.',
    P_CHOOSE_STRONG : 'Cette méthode CHOISIT d\'ignorer les paires faibles pour éliminer ce type de contradiction.',

    P_EXTRACT_WINNER: 'Le résultat est obtenu en extrayant les gagnants successivement (candidat avec uniquement des victoires).',
    P_CONDORCET: 'Cette méthode garantit qu\'un candidat gagnant tous les duels va gagner (appelé gagnant de Condorcet).',
    P_PERCENTAGE_GRAPH : 'Le graphe en % indique l\'ampleur des victoires.'
  });
  //$translateProvider.determinePreferredLanguage();
  $translateProvider.preferredLanguage('fr');
});
app.controller('PrefController', function ($window,$scope, $http,$filter ,$timeout,$anchorScroll,$translate,$location) {
    console.log("locale "+ $location.search().l);
    console.log($location.search());
    $scope.votes = "5:A>C>B>E>D\n5:A>D>E>C>B\n8:B>E>D>A>C\n3:C>A>B>E>D\n"+
    "7:C>A>E>B>D\n2:C>B>A>D>E\n7:D>C>E>B>A\n8:E>B>A>D>C";
    $scope.memphis = function(){
      $scope.votes =
      "42:Memphis>Nashville>Chattanooga>Knoxville\n"+
      "26:Nashville>Chattanooga>Knoxville>Memphis\n"+
      "15:Chattanooga>Knoxville>Nashville>Memphis\n"+
      "17:Knoxville>Chattanooga>Nashville>Memphis\n";
      $scope.init();
    }
    $scope.init = function(){
      $scope.parsedVotes = [];
      $scope.scores = [];
      $scope.result = [];
      $scope.candidates = [];
      $scope.candidatesSet = [];
      $scope.greens = [];
      $scope.message = "";
      $scope.score = undefined;
      $scope.highlightFrom = undefined;
      $scope.highlightTo = undefined;
      if ($scope.visEdges) $scope.visEdges.clear();
      if ($scope.visNodes) $scope.visNodes.clear();
      if ($scope.hierarEdges) $scope.hierarEdges.clear();
      if ($scope.hierarNodes) $scope.hierarNodes.clear();
      $scope.a = 0;
      $scope.b = 0;
    }
    $scope.init();
    $scope.labelForID = function(id){
      for (var i = 0 ; i < $scope.candidates.length ; i++){
        var candA = $scope.candidates[i];
        if (candA.id === id) return candA.label;
      }
    }
    $scope.changeLanguage = function (key) {
      $translate.use(key);
    };
    $scope.parseVotes = function(){
      $scope.message = "We take the textual votes and add them"
      $scope.init();
      var lines = $scope.votes.split("\n");
      var cand = [];
      for (var i = 0 ; i< lines.length ; i++){
        var withoutComment = lines[i].split("#")[0];
        var numberAndVote = withoutComment.split(":");
        if (numberAndVote.length != 2) continue;
        var number = Number(numberAndVote[0]);
        var vote = numberAndVote[1];
        var candidates = vote.split(">");
        var newVote = {number:number , vote:[]};
        for (var c = 0 ; c < candidates.length ; c++){
          var candidate = candidates[c].trim();
          // if it contains =
          if (candidate.indexOf('=') > -1){
            var exaequo = candidate.split('=');
            var set = [];
            for (var ex = 0 ; ex < exaequo.length ; ex++){
              var exOne = exaequo[ex];
              exOne = exOne.trim();
              set.push(exOne);
              cand.push(exOne);
            }
            newVote.vote.push(set);
          }
          else{
            cand.push(candidate);
            newVote.vote.push([candidate]);
          }
        }
        $scope.parsedVotes.push(newVote);
        console.log("Vote is "+newVote.number+"  :: "+ newVote.vote);
      }
      cand.sort();
      console.log(cand);
      $scope.candidatesSet = Array.from(new Set(cand));
      var id = 1;
      for (var i = 0 ; i < $scope.candidatesSet.length ; i++){
        var candA = $scope.candidatesSet[i];
        var node = {id:(i+1),label:candA};
        $scope.candidates.push(node);
        console.log("ADD a node");
        $scope.visNodes.add(node);
        $scope.hierarNodes.add(node);
      }
      console.log($scope.candidatesSet);
      $.smoothScroll({scrollTarget: '#votes'});
      //$anchorScroll('votes');
    };

    $scope.indexOf = function(vote, candidat){
      console.log("indexOf "+ candidat + " dans "+ vote);
      for (var rank = 0 ; rank < vote.length ; rank++){
        var set = vote[rank];
        if (set.indexOf(candidat) > -1) return rank;
      }
      return -1;
    }

    $scope.computeOneScore = function(){
      console.log("score for "+$scope.a+" "+$scope.b);
      var i = $scope.a ; var j = $scope.b;
      var candA = $scope.candidatesSet[$scope.a];
      var candB = $scope.candidatesSet[$scope.b];
      var voteForA = 0;
      var voteForB = 0;
      for (var v = 0 ; v < $scope.parsedVotes.length ; v++){
        var vote = $scope.parsedVotes[v];
        var indexA = $scope.indexOf(vote.vote,candA);
        var indexB = $scope.indexOf(vote.vote,candB);
        //console.log("VOTE "+ vote.vote+"  candA" +candA + "  index " + indexA);
        //console.log("VOTE "+ vote.vote+"  candB" +candB + "  index " + indexB);
        if (indexA < 0 && indexB >= 0)          {
            voteForB += vote.number;}
        else if (indexA >= 0 && indexB < 0)     {
            voteForA += vote.number;}
        else if (indexA < indexB)               {
            voteForA += vote.number;}
        else if (indexB < indexA)               {
            voteForB += vote.number;}
      }
      var edge = {id:1000*i+j, from:(i+1), to:(j+1),arrows:'to',
      label:voteForA-voteForB,color:'black',countW:voteForA, countL:voteForB};
      if (voteForA < voteForB) {
        edge = {id:1000*i+j, from:(j+1), to:(i+1),arrows:'to',
        label:voteForB-voteForA,color:'black',countW:voteForB, countL:voteForA};
      }
      $scope.highlight(edge);
      $scope.scores.push(edge);
      if ($scope.a <= $scope.candidatesSet.length - 3 || $scope.b <= $scope.candidatesSet.length - 2){
        $scope.b++;
        if ($scope.b > $scope.candidatesSet.length - 1) {
          $scope.a++;$scope.b=$scope.a+1;
        }
        $timeout(
          $scope.computeOneScore
          ,500
        );
      }
      else{
        $timeout(function () {
          $scope.timeoutOn = false;
          $scope.rankPairs();
        }, 1000);
      }
    }

    $scope.computeScores = function(){
      $scope.message = "For each pair of candidate, we go through votes to see who wins"
      $scope.scores = [];
      $.smoothScroll({scrollTarget: '#scores'});
      //$anchorScroll('scores');
      $scope.a = 0;
      $scope.b = 1;
      $scope.timeoutOn = true;
      $scope.computeOneScore();
    }

    $scope.rankPairs = function(){
      $scope.message = "We order the pairs by score difference"
      $scope.scores = $filter('orderBy')($scope.scores, ['-label','-countW']);
      $scope.current = 0;
      $scope.greens = [];
      $.smoothScroll({scrollTarget: '#scores'});
      //$anchorScroll('scores');
    }

    $scope.addPair = function(){
      $scope.message = "We add strongest pairs first, if a cycle IN RED is created we delete the latest addition"
      var edge = $scope.scores[$scope.current];
      edge.color = 'green';
      if (edge.label != 0){
        $scope.visEdges.add(edge);
        $scope.greens.push(edge);
      }
      $scope.detectCycle();
    }

    $scope.cycle = function(edges , startId, nodesExplored, edgesExplored){
      for (var e = 0 ; e < edges.length ; e++){
        var edge = edges[e];
        if (edge.from === startId){
          if (nodesExplored.length == 1) console.log("first level edge " +edge.from+ " "+edge.to);
          var recEdges = edgesExplored.slice();
          recEdges.push(edge);
          var recNodes = nodesExplored.slice();
          recNodes.push(edge.to);
          if (nodesExplored.indexOf(edge.to) > -1){
            //cycle
            return recEdges;
          }
          else{
            var recNodes = nodesExplored.slice();
            recNodes.push(edge.to);
            var recEdges = edgesExplored.slice();
            recEdges.push(edge);
            var recRes = $scope.cycle(edges,edge.to, recNodes,recEdges);
            if (recRes.length > 0) return recRes;
          }
        }
      }
      return [];
    }
    $scope.allGreens = function() {return $scope.current > $scope.scores.length-1;}
    $scope.noGreens = function()  {return $scope.greens.length < 1;}
    $scope.detectCycle = function(){
      // we can start from the first node in the green
      var starter = $scope.greens[$scope.greens.length-1].from;
      console.log("Starter detect cycle " + starter);
      console.log("detect cycle edges " + $scope.greens);
      console.log($scope.greens);
      var cycl = $scope.cycle($scope.greens,starter,[starter],[]);
      console.log(cycl);
      if (cycl.length > 0){
        $scope.scores[$scope.current].cycled=true;
        $scope.message = "This makes a cycle (in red) so in 2 seconds, we will remove the latest"
        for (var c = 0 ; c < cycl.length ; c++){
          var edge = cycl[c];
          edge.color = 'red';
          $scope.visEdges.update(edge);
        }
        $scope.timeoutOn = true;
        $timeout(function(){
          $scope.timeoutOn = false;
          var edge = $scope.greens.pop();
          $scope.visEdges.remove(edge);
          for (var c = 0 ; c < $scope.greens.length ; c++){
            var edge = $scope.greens[c];
            edge.color = 'green';
            $scope.visEdges.update(edge);
          }
          $scope.message = "Now we can go to the next pair"
          if ($scope.current > $scope.scores.length-1) {
            $scope.result = [];
            $scope.message = "All pairs have been added";
            //$.smoothScroll({scrollTarget: '#result'});
          }
        }, 1000);
      }
      else{
        $scope.scores[$scope.current].added=true;
        $scope.message = "This makes no cycle so we keep it"
        if ($scope.allGreens()) {
          $scope.result = []
          $scope.message = "All pairs have been added"
        }
      }
      console.log($scope.scores);
      $scope.current++;
    }
    $scope.showSources = function(){
      $scope.message = "We select a node with no incoming arrow"
      for (var c = 0 ; c < $scope.candidates.length ; c++){
        var candidate = $scope.candidates[c];
        if ($scope.indexOf($scope.result,candidate.label) > -1){
          console.log("HEY "+ candidate+" is already in result");
          //continue;
        }
        else{
          var incoming = 0;
          var outgoing = 0;
          for (var g = 0 ; g < $scope.greens.length ; g++){
            var greenEdge = $scope.greens[g];
            if (greenEdge.to === candidate.id) incoming++;
            if (greenEdge.from === candidate.id) outgoing++;
          }
          if (incoming == 0 ){
            candidate.color = 'green';
            $scope.visNodes.update(candidate);
          }
        }
      }
      $scope.timeoutOn = true;
      $timeout(
        function(){
          $scope.moveOneSource();
          $scope.timeoutOn = false;
        }
        ,1000);
    }
    $scope.highlight = function(score){
      $scope.highlightFrom = $scope.labelForID(score.from);
      $scope.highlightTo = $scope.labelForID(score.to);
      console.log("Highlight " +$scope.highlightTo);
      for (var v = 0 ; v < $scope.parsedVotes.length ; v++){
        var vote = $scope.parsedVotes[v];
        var indexA = $scope.indexOf(vote.vote,$scope.highlightFrom);
        var indexB = $scope.indexOf(vote.vote,$scope.highlightTo);
        if (indexA < 0 && indexB >=0) { 
          $scope.parsedVotes[v].highlightScoreL = vote.number;
          $scope.parsedVotes[v].highlightScoreW = "";
        }
        else if (indexA >= 0 && indexB < 0) { 
          $scope.parsedVotes[v].highlightScoreW = vote.number;
          $scope.parsedVotes[v].highlightScoreL = "";
        }
        else if (indexA < indexB) {
          $scope.parsedVotes[v].highlightScoreW = vote.number;
          $scope.parsedVotes[v].highlightScoreL = "";
        }
        else if (indexA > indexB) {
          $scope.parsedVotes[v].highlightScoreL = vote.number;
          $scope.parsedVotes[v].highlightScoreW = "";
        }
        else{
          $scope.parsedVotes[v].highlightScoreW = "";
          $scope.parsedVotes[v].highlightScoreL = "";
        }
      }
      $scope.score = score;
      $.smoothScroll({scrollTarget: '#votes'});
      //$anchorScroll('votes');
    }
    $scope.result = [];
    // remove a source from the green graph and add it to the result (part of the topo sort)
    $scope.moveOneSource = function(){
      $scope.message = "Then we remove it from the graph and add it to the result"
      // if there is only two remaining flush it at once.
      /*if ($scope.greens.length == 1){
        var lastOne = $scope.greens[0];
        var to;
        var from;
        for (var c = 0 ; c < $scope.candidates.length ; c++){
          var candidate = $scope.candidates[c];
          if (lastOne.to === candidate.id) to = candidate;
          if (lastOne.from === candidate.id) from = candidate;
        }
        if ($scope.indexOf($scope.result,from.label) < 0)$scope.result.push([from.label]);
        if ($scope.indexOf($scope.result,to.label) < 0)$scope.result.push([to.label]);
        $scope.visNodes.remove(from);
        $scope.visNodes.remove(to);
        $scope.greens.length = 0;
        $scope.message = "Computation finished ";
        return;
      }*/
      var set=[];
      for (var c = 0 ; c < $scope.candidates.length ; c++){
        var candidate = $scope.candidates[c];
        if (candidate.color === 'green'){
          if ($scope.indexOf($scope.result,candidate.label) < 0)set.push(candidate.label);
          $scope.visNodes.remove(candidate);
          var filtered = $scope.greens.filter(function(edge){
              var res = (edge.to === candidate.id || edge.from === candidate.id);
              if (res) {
                $scope.visEdges.remove(edge);
              }
              if (edge.from === candidate.id){
                edge.label = $filter('number')(100*(edge.countW)/($scope.totalVoters()), 0)+"%";
                $scope.hierarEdges.add(edge);
              }
              return !res;
          });
          $scope.greens = filtered;
        }
      }
      $scope.result.push(set);
    }
    $scope.totalVoters = function(){
      var n = 0 ;
      for (var v = 0 ; v < $scope.parsedVotes.length ; v++){
        n += $scope.parsedVotes[v].number;
      }
      return n;
    }
    $scope.allDone = function(){
      for (var c = 0 ; c < $scope.candidates.length ; c++){
        var candidate = $scope.candidates[c];
        if ($scope.indexOf($scope.result,candidate.label) < 0){
          return false;
        }
      }
      return true;
    }
    console.log("Started controller");
    $scope.visNodes = new vis.DataSet($scope.candidates);
    $scope.visEdges = new vis.DataSet($scope.scores);
    var dataVis = {
        nodes: $scope.visNodes,
        edges: $scope.visEdges
    };
    var options = {
        edges: {    smooth: {type: 'continuous'}    },
        physics: {stabilization: false}
    };
    var container = document.getElementById('mynetwork');
    var network = new vis.Network(container, dataVis, options);

    $scope.hierarNodes = new vis.DataSet([]);
    $scope.hierarEdges = new vis.DataSet([]);
    var hierarData = {
        nodes: $scope.hierarNodes,
        edges: $scope.hierarEdges
    };
    var hierarOptions = {};
    var hierar_container = document.getElementById('hierar');
    var hierar = new vis.Network(hierar_container, hierarData, hierarOptions);
});