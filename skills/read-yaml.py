import math
import random

import networkx as nx
import svgwrite

import yaml
from dataclasses import dataclass
from itertools import permutations

def areIndexConnected(indexA, indexB, gridSize):
    indexA, indexB = (min(indexA, indexB), max(indexA, indexB))
    rowA, colA = (indexA // gridSize, indexA % gridSize)
    rowB, colB = (indexB // gridSize, indexB % gridSize)
    diffRow = abs(rowA - rowB)
    diffCol = abs(colA - colB)
    if diffRow == 0:
        return  diffCol == 1
    elif diffRow > 1:
        return False
    elif diffRow == 1:
        if diffCol == 0:
            return True
        elif rowA % 2 == 0:
            return colA - colB == 1
        elif rowA % 2 == 1:
            return colB - colA == 1
    else:
        return False

def draw_hexagon(dwg, index,  center_x, center_y, row, col, size, text):
    points = []
    for i in range(6):
        angle_rad = math.radians(30 + 60 * i)
        x = center_x + size * math.cos(angle_rad)
        y = center_y + size * math.sin(angle_rad)
        points.append((x, y))
    colors = ["aquamarine", "lightblue", "lightgreen", "tomato"]
    fillColors = random.randrange(0, len(colors))
    fillColor = colors[fillColors]
    if index == 16:
        fillColor = "red"
    if areIndexConnected(16, index, 6):
        fillColor = "blue"
    hexagon = dwg.polygon(points=points, fill=fillColor, stroke='black')
    dwg.add(hexagon)
    text_element = dwg.text(text,
                            insert=(center_x - size * 0.6, center_y + size * 0.2),
                            font_family="Arial",
                            font_size=size * 0.1,
                            transform="rotate(-30, " + str(center_x) + ", " + str(center_y) + ")" )
    dwg.add(text_element)
    text_element = dwg.text("row: " + str(row) + " col: " + str(col),
                            insert=(center_x - size * 0.6, center_y - size * 0.2),
                            font_size=size * 0.1,
                            transform="rotate(-30, " + str(center_x) + ", " + str(center_y) + ")" )
    dwg.add(text_element)

def draw_skill_tree(size, skills):
    gridsize = math.floor(math.sqrt(len(skills)))
    dwg = svgwrite.Drawing(
        filename="skill_tree.svg",
        profile='tiny',
        size=(str(size * (2*gridsize+ 1) ), str(size * (2*gridsize+1))))
    dwg.add(
        dwg.rect(
            insert=(0, 0),
            size=('100%', '100%'),
            rx=None, ry=None,
            fill='rgb(150,150,150)'))
    print("Grid size " + str(gridsize) )
    for element in skills:
        # print(element)
        index = skills.index(element)
        row = index // gridsize
        col = index % gridsize
        x = size * (2 * col + (0 if row % 2 == 0 else 1) + 1)
        y = size *  (0.5 + row * math.sqrt(3) + math.sqrt(3) / 2)
        draw_hexagon(dwg, index, x, y, row, col,  size, element)
    dwg.save()

def read_graph_from_yaml(file_path):
    with open(file_path, 'r') as file:
        graph_data = yaml.safe_load(file)
        return graph_data.get('graph', {})

def read_skills_from_yaml(file_path):
    with open(file_path, 'r') as file:
        data = yaml.safe_load(file)
        return data.get('skills', [])

def read_deps_from_yaml(file_path):
    with open(file_path, 'r') as file:
        data = yaml.safe_load(file)
        return data.get('deps', [])


def bestCount(size):
    tailles = [(2,3), (3, 4), (4, 5), (5, 6), (6, 8), (7, 10), (8, 11), (9, 12)]
    for (row, col) in tailles:
        if row*col >= size:
            return (row, col)


def evaluation(individual, G, col):
    asList = list(individual)
    score = 0
    for (a,b) in G.edges:
        if not areIndexConnected(asList.index(a), asList.index(b), col):
            score -= 1
    return score

if __name__ == "__main__":
    file_path = '5N6.yaml'
    skills = read_skills_from_yaml(file_path)
    deps = read_deps_from_yaml(file_path)
    print(skills)
    print(deps)

    G = nx.DiGraph()
    print("Skills:")
    strings = []
    for node in skills:
        print(f"name: {node['name']}, description: {node['description']}")
        G.add_node(node['name'])

    print("\nDeps:")
    for dep in deps:
        print(f"Source: {dep['from']}, target: {dep['to']}")
        G.add_edge(dep['from'], dep['to'])

    # find a skill distribution that fit in a page and allows arrows to be drawn
    print("size of the skill tree:" + str(len(skills)))
    squareDim = math.floor(math.sqrt(len(skills))) + 1
    print("size of the skill size:" + str(squareDim))

    print(str(G))
    print(str(G.size()))
    #nx.write_yaml(G, "gna.yaml")
    sources = []
    for s in skills:
        # print("yo")
        predCount = sum(1 for dummy in G.predecessors(s["name"]))
        succCount = sum(1 for dummy in G.successors( s["name"]))
        print( "   connection size " + str( predCount + succCount   ) + "  " + s["name"]  )
        if predCount + succCount > 6 :
            print("ALERT ALERT ALERT Too many connecting ones " )
        if predCount == 0 :
            sources.append(s)
            print("Source " + s["name"])
    print("Sources: " + str(sources))
    parts = list(nx.connected_components(G.to_undirected()))
    print("parts " + str(parts))
    strings = []
    for node in skills:
        strings.append(node["name"])
    # chercher 3/4
    (row, col) = bestCount(len(strings))
    print("row " + str(row) + " col " + str(col))
    contentSize = row * col
    print("contentSize " + str(contentSize))
    for i in range(0, contentSize - len(strings)):
        strings.append("___")
    print(str(len(strings)) + " " + str(strings))
    perm = permutations(strings)

    population = []
    # Print the obtained permutations
    for i in perm:
        indiv = list(i)
        random.shuffle(indiv)
        population.append(indiv)
        if len(population) == 100:
            break
    # generations
    bestScore = -100
    for generation in range(1, 400):
        evaluated = {}
        for individual in population:
            score = evaluation(individual, G, col)
            if score > bestScore or score == 0:
                bestScore = score
                print("generation " + str(generation) + "  best score " + str(bestScore))
                draw_skill_tree(50, individual)
            #print("individual " + str(individual)[1:10] + "  score " + str(score))
            evaluated[str(individual)] = score
        # Keep the best 10
        population.sort(key=lambda x: evaluated[str(x)], reverse=True)
        print("average score " + str(sum(evaluated.values())/len(evaluated)))
        #population = population[:10]
        # invert two random elements in the first 10
        for i in range(0, 10):
            a = random.randrange(0, len(population[i]))
            b = random.randrange(0, len(population[i]))
            population[i][a], population[i][b] = population[i][b], population[i][a]
        # shuffle the last 90
        for i in range(10, 100):
            random.shuffle(population[i])
    print("best score " + str(bestScore))
    #draw_skill_tree(50, strings)

